/**
 * @description       : 
 * @author            : Debabrata Mukherjee
 * @group             : 
 * @last modified on  : 06-16-2026
 * @last modified by  : Debabrata Mukherjee
**/
public with sharing class ContactUtility {

    public static Contact createContact(String firstName, String lastName) {
        Contact con = new Contact(
            FirstName = firstName,
            LastName = lastName
        );

        insert con;
        return con;
    }

    public static Integer getContactCount() {
        return [SELECT COUNT() FROM Contact];
    }
}