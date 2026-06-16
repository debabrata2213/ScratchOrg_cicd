/**
 * @description       : 
 * @author            : Debabrata Mukherjee
 * @group             : 
 * @last modified on  : 06-16-2026
 * @last modified by  : Debabrata Mukherjee
**/
@IsTest
private class ContactUtilityTest {

    @IsTest
    static void testCreateContact() {

        Test.startTest();

        Contact con = ContactUtility.createContact(
            'John',
            'Doe'
        );

        Test.stopTest();

        System.assertNotEquals(null, con.Id);
        System.assertEquals('John', con.FirstName);
        System.assertEquals('Doe', con.LastName);
    }

    @IsTest
    static void testGetContactCount() {

        insert new Contact(
            FirstName = 'Jane',
            LastName = 'Smith'
        );

        Test.startTest();

        Integer countContacts = ContactUtility.getContactCount();

        Test.stopTest();

        System.assertEquals(1, countContacts);
    }
}