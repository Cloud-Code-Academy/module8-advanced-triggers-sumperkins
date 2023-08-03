trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    if (Trigger.isBefore){
        if (Trigger.isInsert){
            Opportunity opp = Trigger.new[0];
            if (opp.Type == null && opp.Amount == null){
                opp.Amount = 1000;
            }        
        } else if (Trigger.isDelete){
            for (Opportunity oldOpp : Trigger.old){
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed won opportunity');
                }
            }
        }
    }

    if (Trigger.isAfter){
        if (Trigger.isInsert){
            for (Opportunity opp : Trigger.new){
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                insert tsk;
            }
        } else if (Trigger.isUpdate){
            for (Opportunity opp : Trigger.new){
                for (Opportunity oldOpp : Trigger.old){
                    if (opp.StageName != oldOpp.StageName && opp.Id == oldOpp.Id){
                        opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                    }
                }                
            }
            update Trigger.new;
        } else if (Trigger.isDelete){
            notifyOwnersOpportunityDeleted(Trigger.old);
        } else if (Trigger.isUndelete){
            assignAccountToOpportunity(Trigger.newMap);
        }
    }

    private static void assignAccountToOpportunity(Map<Id,Opportunity> oppNewMap) {        
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : oppNewMap.values()){
            Account acc = [SELECT Id FROM Account];
            if (opp.AccountId == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.AccountId = acc.Id;
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();
    }

    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {[SELECT Id, Email FROM User WHERE Id = :opp.OwnerId].Email};
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        Messaging.sendEmail(mails);
    }
}