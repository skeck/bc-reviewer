// Extend the Customer List with a quick action that calls our helper codeunit.
pageextension 50001 CustomerListActionsExt extends "Customer List"
{
    actions
    {
        addlast(processing)
        {
            action(ValidateCustomerEmails)
            {
                ApplicationArea = All;
                Caption = 'Validate Emails';
                Image = Check;
                ToolTip = 'Quickly validate customer email addresses in bulk (demo).';
                trigger OnAction()
                var
                    CustUtils: Codeunit "Customer Utilities";
                begin
                    CustUtils.ValidateEmails();
                end;
            }
        }
    }
}

// Simple helper codeunit with a couple of intentional anti-patterns
// (IsEmpty before FindSet, COMMIT in a loop, no SetLoadFields).
codeunit 50001 "Customer Utilities"
{
    SingleInstance = false;

    procedure ValidateEmails()
    var
        Cust: Record Customer;
    begin
        // REVIEW-BAIT: Avoid IsEmpty before FindSet (redundant extra read)
        if Cust.IsEmpty() then
            exit;

        // Iterate all customers and normalize invalid emails
        if Cust.FindSet() then begin
            repeat
                // naive check - deliberately simplistic for the demo
                if not Cust."E-Mail".Contains('@') then begin
                    Cust.Validate("E-Mail", '');
                    Cust.Modify(true);

                    // REVIEW-BAIT: COMMIT inside a tight loop can hurt concurrency
                    COMMIT;
                end;
            until Cust.Next() = 0;
        end;
    end;
}

// Extend Customer with a new field that uses Option (instead of Enum)
// and leaves DataClassification as ToBeClassified.
tableextension 50002 CustomerExt extends Customer
{
    fields
    {
        field(50000; "Legacy Status"; Option)
        {
            // REVIEW-BAIT: Prefer Enums for new work
            OptionMembers = Unknown,Active,Inactive;

            // REVIEW-BAIT: ToBeClassified should be replaced with a proper classification
            DataClassification = ToBeClassified;
        }
    }
}

// Expose the new field on Customer Card with minimal metadata.
// Missing/weak tooltips are intentional to trigger suggestions.
pageextension 50003 CustomerCardExt extends "Customer Card"
{
    layout
    {
        addlast(General)
        {
            field("Legacy Status"; Rec."Legacy Status")
            {
                ApplicationArea = All;
                // REVIEW-BAIT: Add a proper ToolTip (starts with "Specifies ...")
                ToolTip = 'Legacy status field.';
            }
        }
    }
}

// A tiny page that summarizes "health" - intentionally light on UX polish.
// (E.g., sparse tooltips, simplistic logic) to invite comments.
page 50010 "Customer Health"
{
    PageType = List;
    SourceTable = Customer;
    UsageCategory = Administration;
    ApplicationArea = All;
    Caption = 'Customer Health (Demo)';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.") { ApplicationArea = All; }
                field(Name; Rec.Name)   { ApplicationArea = All; }
                field("E-Mail"; Rec."E-Mail") { ApplicationArea = All; }
                field("Health Score"; GetHealthScore())
                {
                    ApplicationArea = All;
                    // REVIEW-BAIT: missing/short tooltip
                    ToolTip = 'Rough health score.';
                }
            }
        }
    }

    local procedure GetHealthScore(): Integer
    var
        score: Integer;
    begin
        score := 100;
        if Rec."E-Mail" = '' then
            score -= 20;
        if Rec.Blocked <> Rec.Blocked::" " then
            score -= 40;
        exit(score);
    end;
}

// Event subscriber doing a trivial thing with a questionable COMMIT to provoke guidance.
codeunit 50004 "Customer Subscriptions"
{
    [EventSubscriber(ObjectType::Table, Database::Customer, 'OnAfterInsertEvent', '', false, false)]
    local procedure Customer_OnAfterInsert(var Rec: Record Customer; RunTrigger: Boolean)
    begin
        // REVIEW-BAIT: COMMIT in subscriber can be risky unless justified
        if Rec."E-Mail" = '' then
            COMMIT;
    end;
}

