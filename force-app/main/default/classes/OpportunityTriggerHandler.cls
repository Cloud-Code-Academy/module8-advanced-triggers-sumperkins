public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    private List<Task> tasksToCreate; // Maintain a list of tasks to insert

    public OpportunityTriggerHandler() {
        super();
        this.tasksToCreate = new List<Task>();
    }

    public override void beforeInsert() {
        setDefaultOpportunityType((List<Opportunity>) Trigger.new);
    }

    public override void beforeUpdate() {
        validateOpportunityAmount((List<Opportunity>) Trigger.new);
        setPrimaryContact((List<Opportunity>) Trigger.new);
        appendStageChangeToDescription((List<Opportunity>) Trigger.new, (Map<Id, Opportunity>) Trigger.oldMap);
    }

    public override void beforeDelete() {
        preventClosedOpportunityDeletion((List<Opportunity>) Trigger.old);
        preventClosedWonBankingDeletion((List<Opportunity>) Trigger.old);
    }

    public override void afterInsert() {
        createTasksForNewOpportunities((List<Opportunity>) Trigger.new);
        try {
            insertTasks(); // Perform DML operation outside of trigger handler
        } catch (DmlException e) {
            System.debug('Error inserting tasks: ' + e.getMessage());
            // Handle exception as needed (e.g., log, retry, notify user)
        }
    }

    public override void afterUpdate() {
        appendStageChangeToDescription((List<Opportunity>) Trigger.new, (Map<Id, Opportunity>) Trigger.oldMap);
        try {
            insertTasks(); // Perform DML operation outside of trigger handler
        } catch (DmlException e) {
            System.debug('Error inserting tasks: ' + e.getMessage());
            // Handle exception as needed (e.g., log, retry, notify user)
        }
    }

    public override void afterDelete() {
        notifyOwnersOpportunityDeleted(Trigger.old);
        // Perform other DML operations if necessary
    }

    public override void afterUndelete() {
        assignPrimaryContact((Map<Id, Opportunity>) Trigger.newMap);
        // Perform other DML operations if necessary
    }

    private void setDefaultOpportunityType(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.Type == null) {
                opp.Type = 'New Customer';
            }
        }
    }

    private void validateOpportunityAmount(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.Amount < 5000) {
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
    }

    private void setPrimaryContact(List<Opportunity> opps) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opps) {
            accountIds.add(opp.AccountId);
        }

        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }

        for (Opportunity opp : opps) {
            if (opp.Primary_Contact__c == null) {
                if (accountIdToContact.containsKey(opp.AccountId)) {
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }

    private void appendStageChangeToDescription(List<Opportunity> opps, Map<Id, Opportunity> oldOppMap) {
        for (Opportunity opp : opps) {
            Opportunity oldOpp = oldOppMap.get(opp.Id);
            if (opp.StageName != oldOpp.StageName) {
                opp.Description = (opp.Description != null ? opp.Description : '') + '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
            }
        }
    }

    private void preventClosedOpportunityDeletion(List<Opportunity> opps) {
        for (Opportunity oldOpp : opps) {
            if (oldOpp.IsClosed) {
                oldOpp.addError('Cannot delete closed opportunity');
            }
        }
    }

    private void preventClosedWonBankingDeletion(List<Opportunity> opps) {
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, Industry FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :opps)]);
        for (Opportunity opp : opps) {
            if (opp.StageName == 'Closed Won' && accounts.get(opp.AccountId).Industry == 'Banking') {
                opp.addError('Cannot delete a closed won opportunity for a banking account');
            }
        }
    }

    private void createTasksForNewOpportunities(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            tasksToCreate.add(tsk); // Add task to the list instead of inserting directly
        }
    }

    private void insertTasks() {
        if (!tasksToCreate.isEmpty()) {
            insert tasksToCreate;
        }
    }

    public void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity opp : opps) {
            ownerIds.add(opp.OwnerId);
        }

        Map<Id, User> owners = new Map<Id, User>([SELECT Id, Email FROM User WHERE Id IN :ownerIds]);

        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : opps) {
            User owner = owners.get(opp.OwnerId);
            if (owner != null && owner.Email != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { owner.Email });
                mail.setSubject('Opportunity Deleted : ' + opp.Name);
                mail.setPlainTextBody('Your Opportunity: ' + opp.Name + ' has been deleted.');
                mails.add(mail);
            }
        }

        try {
            Messaging.sendEmail(mails);
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }

    public void assignPrimaryContact(Map<Id, Opportunity> oppNewMap) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : oppNewMap.values()) {
            accountIds.add(opp.AccountId);
        }

        Map<Id, Account> accMap = new Map<Id, Account>([SELECT Id, Name, (SELECT Id FROM Contacts WHERE Title = 'VP Sales') FROM Account WHERE Id IN :accountIds]);

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : oppNewMap.values()) {
            if (opp.Primary_Contact__c == null && !accMap.get(opp.AccountId).Contacts.isEmpty()) {
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = accMap.get(opp.AccountId).Contacts[0].Id;
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();
    }
}
