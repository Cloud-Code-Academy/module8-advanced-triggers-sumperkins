@IsTest
public with sharing class TriggerBestPracticeTest {
    
    // Part 1 - AccountTrigger Changes
    /*
    * Update the AccountTrigger.trigger to use the AccountTriggerHandler class
    * You can use the AccountTrigger provided or the previous one you created is last weeks lecture
    * If you are using last lectures AccountTrigger you created. Copy and paste the code from the previous week's project into this project and deploy it to your org
    * Implement the AccountHelper class methods for each of the distinct trigger logic from the AccountTrigger
    * All of the AccountTrigger tests should pass if you have implemented the AccountHelper class correctly
    */

    @IsTest 
    static void testAccountTrgger_setTypeProspect() {
        // Prepare the test data
        List<Account> accountTypeProspect = new List<Account>();
        List<Account> accountTypeNotChange = new List<Account>();
        for(Integer i = 0; i < 400; i++) {
            if (Math.mod(i, 2) == 0){
                accountTypeProspect.add(new Account(Name = 'Test Account ' + i));
            } else {
                accountTypeNotChange.add(new Account(Name = 'Test Account ' + i, Type = 'Customer'));
            }
            
        }
        
        // Perform the test
        Test.startTest();
        insert accountTypeProspect;
        insert accountTypeNotChange;
        Test.stopTest();
        
        // Retrieve the accounts again
        List<Account> prospectAccounts = [SELECT Id, Type FROM Account WHERE Type = 'Prospect'];

        // Assert that the number of accounts inserted is correct
        System.assertEquals(200, prospectAccounts.size(), 'Number of accounts inserted is incorrect.');
        
        // Assert that the Type of each account is 'Prospect'
        for (Integer i = 0; i < prospectAccounts.size(); i++) {
            Account acc = prospectAccounts[i];
            System.assertEquals('Prospect', acc.Type, 'Account Type is incorrect.');
            if (Math.mod(i, 2) == 0){
                acc.Type = 'Customer';
            } else {
                acc.Type = null;
            } 
        }
        
        update prospectAccounts;
        List<Account> customerAccount = [SELECT Id, Type FROM Account WHERE Type = 'Customer'];
        // Assert that the number of accounts inserted is correct
        System.assertEquals(300, customerAccount.size(), 'Number of accounts updated is incorrect.');

    }

    /*
    * Account Trigger
    * When an account is inserted copy the shipping address to the billing address.
    * Trigger should only fire on insert.
    */
    @IsTest 
    static void testAccountTrgger_addressCopy() {
        // Prepare the test data
        List<Account> accountsToInsert = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            Account acc = new Account(
                Name = 'Test Account ' + i,
                ShippingStreet = '123 Test St ' + i,
                ShippingCity = 'Test City ' + i,
                ShippingState = 'TS',
                ShippingPostalCode = '12345',
                ShippingCountry = 'Test Country ' + i,
                AnnualRevenue = i
            );
            accountsToInsert.add(acc);
        }

        // Perform the test
        Test.startTest();
        insert accountsToInsert;
        Test.stopTest();

        // Retrieve the accounts again
        List<Account> insertedAccounts = [SELECT Id, 
                                          BillingStreet, 
                                          BillingCity, 
                                          BillingState, 
                                          BillingPostalCode, 
                                          BillingCountry 
                                          FROM Account 
                                          WHERE Id IN :accountsToInsert
                                          ORDER BY AnnualRevenue ASC];

        // Assert that the Billing Address fields have been correctly copied from the Shipping Address for each account
        for (Integer i = 0; i < insertedAccounts.size(); i++) {
            System.assertEquals('123 Test St ' + i, insertedAccounts[i].BillingStreet, 'BillingStreet not correctly copied for account ' + i + '.');
            System.assertEquals('Test City ' + i, insertedAccounts[i].BillingCity, 'BillingCity not correctly copied for account ' + i + '.');
            System.assertEquals('TS', insertedAccounts[i].BillingState, 'BillingState not correctly copied for account ' + i + '.');
            System.assertEquals('12345', insertedAccounts[i].BillingPostalCode, 'BillingPostalCode not correctly copied for account ' + i + '.');
            System.assertEquals('Test Country ' + i, insertedAccounts[i].BillingCountry, 'BillingCountry not correctly copied for account ' + i + '.');
            insertedAccounts[i].ShippingStreet = '321 Test St';
        }

        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true; 
        Database.update(insertedAccounts, dml); 

        List<Account> updatedAccounts = [SELECT Id, BillingStreet, AnnualRevenue FROM Account WHERE Id IN :insertedAccounts ORDER BY AnnualRevenue ASC];
        // Assert that billing address has not been changed
        for (Account acc : updatedAccounts) {
            System.assertEquals('123 Test St ' + String.valueOf(acc.AnnualRevenue), acc.BillingStreet, 'Billing Street should not change on update.');
        }
    }

    /*
    * Account Trigger
    * When an account is inserted set the rating to 'Hot' if the Phone, Website, and Fax is not empty.
    * Trigger should only fire on insert.
    */
    @IsTest 
    static void testAccountTrgger_setRating() {
        // Prepare the test data
        List<Account> accountsToInsert = new List<Account>();
        List<Account> accountsNotHot = new List<Account>();
        for (Integer i = 0; i < 400; i++) {
            if (Math.mod(0,2) == 0) {
                Account acc = new Account(
                    Name = 'Test Account ' + i,
                    Phone = '1234567890',
                    Website = 'www.testwebsite' + i + '.com',
                    Fax = '0987654321'
                );
                accountsToInsert.add(acc);
            } else {
                Account acc = new Account(
                    Name = 'Test Account ' + i,
                    Rating = 'Warm'
                );
                accountsNotHot.add(acc);
            }            
        }

        // Perform the test
        Test.startTest();
        insert accountsToInsert;
        insert accountsNotHot;
        Test.stopTest();

        // Retrieve the accounts again
        List<Account> insertedAccounts = [SELECT Id, Rating FROM Account WHERE Id IN :accountsToInsert];

        // Assert that the Rating field has been correctly set to 'Hot' for each account
        for (Integer i = 0; i < insertedAccounts.size(); i++) {
            System.assertEquals('Hot', insertedAccounts[i].Rating, 'Rating not correctly set to Hot for account ' + i + '.');
            insertedAccounts[i].Rating = null;
        }

        update insertedAccounts;
        List<Account> updatedAccounts = [SELECT Id, Rating FROM Account WHERE Id IN :insertedAccounts];
        for (Account acc : updatedAccounts) {
            System.assertEquals(null, acc.Rating, 'Rating should not change on update.');
        }

        // Retrieve the accounts again
        List<Account> insertedAccountsNotHot = [SELECT Id, Rating FROM Account WHERE Id IN :accountsNotHot];

        // Assert that the Rating field has not been changed for each account
        for (Integer i = 0; i < insertedAccountsNotHot.size(); i++) {
            System.assertEquals('Warm', insertedAccountsNotHot[i].Rating, 'Rating incorrectly changed for account ' + i + '.');
        }
    }

    /*
    * Account Trigger
    * When an account is inserted create a contact related to the account with the following default values:
    * LastName = 'DefaultContact'
    * Email = 'default@email.com'
    * Trigger should only fire on insert.
    */
    @IsTest
    static void testAccountTrgger_defaultContact() {
        // Prepare the test data
        List<Account> accountsToInsert = new List<Account>();
        for (Integer i = 0; i < 400; i++) {
            Account acc = new Account(Name = 'Test Account ' + i);
            accountsToInsert.add(acc);
        }

        // Perform the test
        Test.startTest();
        insert accountsToInsert;
        Test.stopTest();

        // Retrieve the newly created Contacts
        List<Contact> contacts = [SELECT Id, LastName, Email, AccountId FROM Contact WHERE AccountId IN :accountsToInsert];

        // Assert that the correct number of Contacts has been created
        System.assertEquals(400, contacts.size(), 'Incorrect number of Contacts created.');

        // Assert that each Contact has the expected field values
        for (Contact con : contacts) {
            System.assertEquals('DefaultContact', con.LastName, 'Contact LastName is incorrect.');
            System.assertEquals('default@email.com', con.Email, 'Contact Email is incorrect.');
            System.assertNotEquals(null, con.AccountId, 'Contact AccountId is null.');
        }

        delete contacts;
        for (Account acc : accountsToInsert) {
            acc.Name = 'Test Account Updated';
        }

        update accountsToInsert;

        List<Contact> updatedContacts = [SELECT Id, LastName, Email, AccountId FROM Contact];
        // Assert that the Contacts no contacts exists
        System.assertEquals(0, updatedContacts.size(), 'Contacts should not exist.');
    }



    //Part 2 - AnotherOpportunityTrigger Refactor
    /*
    * AnotherOpportunityTrigger was created by a previous developer and is causing some issues.'
    * The trigger does not follow best practices and needs to be refactored.
    * Look for the following issues and refactor the trigger to follow best practices:
    * - Avoid nested for loop - 1 instance
    * - Avoid DML inside for loop - 1 instance
    * - Bulkify Your Code - 1 instance
    * - Avoid SOQL Query inside for loop - 2 instances
    * All of the AnotherOpportunityTrigger tests should pass if you have refactored the trigger correctly
    */



    //Part 3 - OpportunityTriggerHandler Implementation
    /*
    * Create a new OpportunityTriggerHandler class that implements TriggerHandler
    * Combine the OpportunityTrigger and AnotherOpportunityTrigger into the new OpportunityTriggerHandler class
    * Only one OpportunityTrigger needs to run the OpportunityTriggerHandler class and the other can be commented out
    * All of the OpportunityTrigger and AnotherOpportunityTrigger tests should pass if you have implemented the OpportunityTriggerHandler class correctly
    */






}