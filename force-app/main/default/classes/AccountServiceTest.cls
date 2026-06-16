/**
 * @description       : 
 * @author            : Debabrata Mukherjee
 * @group             : 
 * @last modified on  : 06-16-2026
 * @last modified by  : Debabrata Mukherjee
**/
@IsTest
private class AccountServiceTest {

    @TestSetup
    static void makeData() {

        Account acc1 = new Account(
            Name = 'Acme Corp',
            AccountTier__c = 'Gold',
            Industry = 'Technology',
            Phone = '5550001111'
        );

        Account acc2 = new Account(
            Name = 'Globex Inc',
            AccountTier__c = 'Bronze',
            Industry = 'Finance'
        );

        insert new List<Account>{ acc1, acc2 };

        Contact c1 = new Contact(
            FirstName = 'Alice',
            LastName = 'Smith',
            Email = 'alice@acme.com',
            Phone = '5550002222',
            AccountId = acc1.Id
        );

        Contact c2 = new Contact(
            FirstName = 'Bob',
            LastName = 'Jones',
            Email = 'bob@acme.com',
            AccountId = acc1.Id
        );

        Contact c3 = new Contact(
            FirstName = 'Carol',
            LastName = 'White',
            AccountId = acc2.Id
        );

        insert new List<Contact>{ c1, c2, c3 };
    }

    @IsTest
    static void testGetAccountsWithContacts_returnsData() {

        Test.startTest();
        List<Account> results =
            AccountService.getAccountsWithContacts();
        Test.stopTest();

        System.assert(
            results.size() > 0,
            'Should return accounts'
        );

        Boolean foundAcme = false;

        for (Account a : results) {
            if (a.Name == 'Acme Corp') {
                foundAcme = true;
                System.assertEquals(
                    2,
                    a.Contacts.size(),
                    'Acme should have 2 contacts'
                );
            }
        }

        System.assert(
            foundAcme,
            'Acme Corp should be returned'
        );
    }

    @IsTest
    static void testUpdateAccountTier_updatesSuccessfully() {

        Account acc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Globex Inc'
            LIMIT 1
        ];

        Test.startTest();
        AccountService.updateAccountTier(
            acc.Id,
            'Silver'
        );
        Test.stopTest();

        Account updated = [
            SELECT AccountTier__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'Silver',
            updated.AccountTier__c
        );
    }

    @IsTest
    static void testRecalculatePriorityScores_runsSuccessfully() {

        Account acc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Acme Corp'
            LIMIT 1
        ];

        Test.startTest();

        AccountService.recalculatePriorityScores(
            new Set<Id>{ acc.Id }
        );

        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testRecalculatePriorityScores_emptySet() {

        Test.startTest();

        AccountService.recalculatePriorityScores(
            new Set<Id>()
        );

        Test.stopTest();

        System.assert(true);
    }
}