/**
 * AccountService
 * Business logic for Account and Contact management.
 */
public with sharing class AccountService {

    /**
     * Returns all Accounts with their related Contacts,
     * ordered by Name. Used by AccountDashboard LWC.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccountsWithContacts() {
        return [
            SELECT Id, Name, AccountTier__c, Industry, Phone,
                (SELECT Id, FirstName, LastName, Email, PriorityScore__c
                 FROM Contacts
                 ORDER BY PriorityScore__c DESC)
            FROM Account
            ORDER BY Name ASC
            LIMIT 200
        ];
    }

    /**
     * Updates the AccountTier__c of a given Account.
     */
    @AuraEnabled
    public static void updateAccountTier(Id accountId, String tier) {
        Account acc = new Account(Id = accountId, AccountTier__c = tier);
        update acc;
    }

    /**
     * Recalculates PriorityScore__c for all Contacts
     * on the provided Account Ids. Called from triggers.
     */
    public static void recalculatePriorityScores(Set<Id> accountIds) {
        List<Contact> toUpdate = new List<Contact>();
        for (Contact c : [
            SELECT Id, AccountId, Email, Phone
            FROM Contact
            WHERE AccountId IN :accountIds
        ]) {
            Integer score = 0;
            if (c.Email != null)  score += 10;
            if (c.Phone != null)  score += 5;
            toUpdate.add(new Contact(Id = c.Id, PriorityScore__c = score));
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}
