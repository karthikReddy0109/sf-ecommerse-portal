public with sharing class OverdueOrderBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Integer totalProcessed = 0;
    private Integer totalOverdue = 0;
    public Database.QueryLocator start(Database.BatchableContext bc){
        Order_Config__mdt orderConfigRecord = [
            SELECT Overdue_Order_Days__c 
            FROM Order_Config__mdt 
            WHERE DeveloperName = 'Default' 
            LIMIT 1
        ];
        Integer overDueDays = Integer.valueOf(orderConfigRecord.Overdue_Order_Days__c);
        Date cutoffDate = Date.today().addDays(-overDueDays);
        return Database.getQueryLocator([
            SELECT Id, Status__c, Is_Overdue__c, Owner.Email, Name, OwnerId, Owner.Name
            FROM Order__c
            WHERE Is_Overdue__c = false
            AND Order_Date__c < :cutoffDate
            AND Status__c IN ('Processing', 'Confirmed')
        ]);
    }
    public void execute(Database.BatchableContext bc, List<Order__c> scope){
        List<Order__c> ordersToUpdate = new List<Order__c>();
        List<Task> tasksToCreate = new List<Task>();
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        for(Order__c order : scope){
            ordersToUpdate.add(new Order__c(
                Id = order.Id,
                Is_Overdue__c = true
            ));
            tasksToCreate.add(new Task(
                Subject = 'Order overdue : ' + order.Name,
                OwnerId = order.OwnerId,
                ActivityDate = System.today(),
                Priority = 'High',
                WhatId = order.Id
            ));
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setSubject('Order overdue ' + order.Name);
            email.setPlainTextBody(
                'Dear ' + order.Owner.Name + ',\n\n' +
                'Order ' + order.Name + ' is overdue.\n' +
                'A task has been created for your review.\n\n' +
                'Please take immediate action.'
            );
            email.setToAddresses(new List<String>{order.Owner.Email});
            emailList.add(email);
        }
        if(!ordersToUpdate.isEmpty()){
            try{
                update ordersToUpdate;
            }catch(DmlException e){
                System.debug('An exception occured ' + e.getMessage());
            }
        }
        if(!tasksToCreate.isEmpty()){
            try{
                insert tasksToCreate;
            }catch(DmlException e){
                System.debug('An exception occured ' + e.getMessage());
            }
        }
        if(!emailList.isEmpty()){
            Messaging.sendEmail(emailList);
        }
        totalProcessed += scope.size();
        totalOverdue += ordersToUpdate.size();
    }
    public void finish(Database.BatchableContext bc){
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject('Over due order batch processed successfully');
        mail.setPlainTextBody('Total Processed : ' + totalProcessed, ' Total Overdue : ' + totalOverdue);
        mail.setToAddresses(new List<String>{'karthikreddy1909@gmail.com'});
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
    }
}