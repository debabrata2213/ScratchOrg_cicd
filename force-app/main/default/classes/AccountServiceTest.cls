@IsTest
private class AccountServiceTest {

    /**
     * Sets up shared test data using @TestSetup so it runs once
     * for all test methods in this class.
     */
    @TestSetup
    static void makeData() {
        Account acc1 = new Account(
            Name          = 'Acme Corp',
            AccountTier__c = 'Gold',
            Industry      = 'Technology',
            Phone         = '5550001111'
        );
        Account acc2 = new Account(
            Name          = 'Globex Inc',
            AccountTier__c = 'Bronze',
            Industry      = 'Finance'
        );
        insert new List<Account>{ acc1, acc2 };

        Contact c1 = new Contact(
            FirstName = 'Alice', LastName = 'Smith',
            Email     = 'alice@acme.com', Phone = '5550002222',
            AccountId = acc1.Id
        );
        Contact c2 = new Contact(
            FirstName = 'Bob', LastName = 'Jones',
            Email     = 'bob@acme.com',
            AccountId = acc1.Id
        );
        Contact c3 = new Contact(
            FirstName = 'Carol', LastName = 'White',
            AccountId = acc2.Id
        );
        insert new List<Contact>{ c1, c2, c3 };
    }

    @IsTest
    static void testGetAccountsWithContacts_returnsData() {
        Test.startTest();
        List<Account> results = AccountService.getAccountsWithContacts();
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Should return at least one account');
        Boolean foundAcme = false;
        for (Account a : results) {
            if (a.Name == 'Acme Corp') {
                foundAcme = true;
                System.assertEquals(2, a.Contacts.size(), 'Acme should have 2 contacts');
            }
        }
        System.assert(foundAcme, 'Acme Corp should be in results');
    }

    @IsTest
    static void testUpdateAccountTier_updatesSuccessfully() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Globex Inc' LIMIT 1];

        Test.startTest();
        AccountService.updateAccountTier(acc.Id, 'Silver');
        Test.stopTest();

        Account updated = [SELECT AccountTier__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Silver', updated.AccountTier__c, 'Tier should be updated to Silver');
    }

    @IsTest
    static void testRecalculatePriorityScores_emailAndPhone() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];

        Test.startTest();
        AccountService.recalculatePriorityScores(new Set<Id>{ acc.Id });
        Test.stopTest();

        // Alice has email + phone → score = 15
        Contact alice = [
            SELECT PriorityScore__c FROM Contact WHERE Email = 'alice@acme.com'
        ];
        System.assertEquals(15, alice.PriorityScore__c, 'Alice should score 15 (email+phone)');

        // Bob has email only → score = 10
        Contact bob = [
            SELECT PriorityScore__c FROM Contact WHERE Email = 'bob@acme.com'
        ];
        System.assertEquals(10, bob.PriorityScore__c, 'Bob should score 10 (email only)');
    }

    @IsTest
    static void testRecalculatePriorityScores_noEmailNoPhone() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Globex Inc' LIMIT 1];

        Test.startTest();
        AccountService.recalculatePriorityScores(new Set<Id>{ acc.Id });
        Test.stopTest();

        Contact carol = [
            SELECT PriorityScore__c FROM Contact WHERE LastName = 'White'
        ];
        System.assertEquals(0, carol.PriorityScore__c, 'Carol should score 0 (no email, no phone)');
    }

    @IsTest
    static void testUpdateAccountTier_invalidTier_throwsException() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AccountService.updateAccountTier(acc.Id, 'Platinum');
        } catch (DmlException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Invalid picklist value should throw DmlException');
    }
}
