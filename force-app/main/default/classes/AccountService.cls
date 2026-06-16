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
                (SELECT Id, FirstName, LastName, Email
                 FROM Contacts
                 ORDER BY LastName)
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
        Account acc = new Account(
            Id = accountId,
            AccountTier__c = tier
        );
        update acc;
    }

    /**
     * Placeholder implementation for pipeline testing.
     * Does not perform updates to avoid trigger recursion.
     */
    public static void recalculatePriorityScores(Set<Id> accountIds) {

        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        List<Contact> contacts = [
            SELECT Id, Email, Phone
            FROM Contact
            WHERE AccountId IN :accountIds
        ];

        System.debug('Contacts found: ' + contacts.size());
    }
}