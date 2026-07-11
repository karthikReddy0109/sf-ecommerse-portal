public with sharing class OrderTriggerHandler {
    private static String recalculateTier(Decimal totalSpend, Map<String, Loyalty_Tier_Config__mdt> loyaltyTierConfigMap){
        String tier = 'Bronze';
        for(Loyalty_Tier_Config__mdt config : loyaltyTierConfigMap.values()){
            if(totalSpend >= config.Min_Spend__c){
                tier = config.Tier__c;
            }
        }
        return tier;
    }
    private static void addLoyaltyPointsToCustomer(Set<Id> customers, List<Order__c> orderList){
        List<Customer_Loyalty__c> customerLoyaltyList = [
            SELECT Id, Customer__c, Tier__c, Loyalty_Points__c, Total_Orders__c, Total_Spend__c
            FROM Customer_Loyalty__c
            WHERE Customer__c IN: customers
        ];
        
        Map<Id, Customer_Loyalty__c> idToCustomerLoyalty = new Map<Id, Customer_Loyalty__c>();
        for(Customer_Loyalty__c cl : customerLoyaltyList){
            idToCustomerLoyalty.put(cl.Customer__c, cl);
        }
        List<Customer_Loyalty__c> newLoyaltyRecords = new List<Customer_Loyalty__c>();
        Set<Id> accountsWithNewLoyalty = new Set<Id>();
        for(Order__c deliveredOrder : orderList){
            if(!idToCustomerLoyalty.containsKey(deliveredOrder.Customer__c)
            && !accountsWithNewLoyalty.contains(deliveredOrder.Customer__c)){
                accountsWithNewLoyalty.add(deliveredOrder.Customer__c);
                newLoyaltyRecords.add(new Customer_Loyalty__c(
                    Customer__c = deliveredOrder.Customer__c,
                    Tier__c = 'Bronze',
                    Loyalty_Points__c = 0,
                    Total_Spend__c = 0,
                    Total_Orders__c = 0
                ));
            }
        }
        if(!newLoyaltyRecords.isEmpty()){
            insert newLoyaltyRecords;
            for(Customer_Loyalty__c cl : newLoyaltyRecords){
                idToCustomerLoyalty.put(cl.Customer__c, cl);
            }
        }
        Map<String, Loyalty_Tier_Config__mdt> tierConfigMap = new Map<String, Loyalty_Tier_Config__mdt>();
        for(Loyalty_Tier_Config__mdt config : Loyalty_Tier_Config__mdt.getAll().values()){
            tierConfigMap.put(config.Tier__c, config);
        }
        List<Customer_Loyalty__c> loyaltyRecordsToUpdate = new List<Customer_Loyalty__c>();
        for(Order__c order : orderList){
            Customer_Loyalty__c loyaltyRec = idToCustomerLoyalty.get(order.Customer__c);
            if(loyaltyRec == null || loyaltyRec.Tier__c == null) continue;
            Decimal pointsPerRupee = tierConfigMap.get(loyaltyRec.Tier__c).Points_Per_Rupee__c;
            Decimal pointsEarned = order.Final_Amount__c * pointsPerRupee;
            loyaltyRec.Loyalty_Points__c = (loyaltyRec.Loyalty_Points__c == null ? 0 : loyaltyRec.Loyalty_Points__c) + pointsEarned;
            loyaltyRec.Total_Orders__c = loyaltyRec.Total_Orders__c == null ? 1 : loyaltyRec.Total_Orders__c + 1;
            Decimal totalSpend = loyaltyRec.Total_Spend__c == null ? order.Final_Amount__c : loyaltyRec.Total_Spend__c + order.Final_Amount__c;
            loyaltyRec.Total_Spend__c = totalSpend;
            
            String newTier = recalculateTier(totalSpend, tierConfigMap);
            loyaltyRec.Tier__c = newTier;
            loyaltyRecordsToUpdate.add(loyaltyRec);
        }
        if(!loyaltyRecordsToUpdate.isEmpty()){
            update loyaltyRecordsToUpdate;
        }
    }
    public static void addLoyaltyPoints(List<Order__c> orderList, Map<Id, Order__c> orderOldMap){
        Set<Id> customersSet = new Set<Id>();
        List<Order__c> deliveredOrders = new List<Order__c>();
        for(Order__c order : orderList){
            if(order.Customer__c == null) continue;
            Boolean isStatusChanged = order.Status__c != orderOldMap.get(order.Id).Status__c;
            if(isStatusChanged && order.Status__c == 'Delivered'){
                customersSet.add(order.Customer__c);
                deliveredOrders.add(order);
            }
        }
        if(customersSet.isEmpty()) return;
        addLoyaltyPointsToCustomer(customersSet, deliveredOrders);
    }
    public static void sendOrderConfirmationEmail(List<Order__c> ordersList){
        EmailTemplate orderEmailTemplate = [
            SELECT Id 
            FROM EmailTemplate
            WHERE DeveloperName = 'Order_Confirmation_Notice'
            LIMIT 1
        ];
        List<Messaging.SingleEmailMessage> mailList = new List<Messaging.SingleEmailMessage>();

        for(Order__c order : ordersList){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(orderEmailTemplate.Id);
            mail.setWhatId(order.Id);
            mail.setTargetObjectId(order.Contact__c);
            mailList.add(mail);
        }
        if(mailList.isEmpty()) return;
        Messaging.SendEmailResult[] results = Messaging.sendEmail(mailList);
        for(Messaging.SendEmailResult res : results){
            if(!res.isSuccess()){
                System.debug('Email failure reason : ' + res.getErrors()[0].getMessage());
            }
        }
    }
    
    public static void captureConfirmedOrders(List<Order__c> orders, Map<Id, Order__c> orderOldMap){
        Set<Id> orderIdSet = new Set<Id>();
        for(Order__c order : orders){
            if(orderOldMap != null && order.Status__c == 'Confirmed' && orderOldMap.get(order.Id).Status__c != 'Confirmed'){
                orderIdSet.add(order.Id);
            }
        }
        if(!orderIdSet.isEmpty()){
            System.enqueueJob(new ValidateOrderQueueable(orderIdSet));
        }
    }
}


/*
 * Scenario 1 — Order Processing Pipeline (Queueable Chain)
When an Order's Status moves to Confirmed, it should automatically kick off a 4-step processing pipeline:

Step 1 — Validate — verify all line items still have sufficient stock, verify customer details are complete. Set Processing_Stage__c to Validated.
Step 2 — Payment Confirmation — make a callout to a mock payment gateway confirming the payment. Set Processing_Stage__c to Payment Confirmed.
Step 3 — Fulfillment — deduct stock for all line items (reuse ProductService or OrderService logic). Set Processing_Stage__c to Fulfilled.
Step 4 — Shipping — make a callout to mock shipping API, get a tracking number back. Create a Shipment__c record. Set Processing_Stage__c to Shipped. Update Order__c.Tracking_Number__c.

If any step fails — set Order__c.Status__c to Failed with a meaningful error message in Notes__c. Do not proceed to the next step.
Scenario 2 — Overdue Order Detection (Batch)
Every morning a batch job runs and finds all Orders where:

Status__c is Processing or Confirmed
Order_Date__c is more than 3 days ago (threshold from Order_Config__mdt)
Not already flagged

For each overdue Order:

Update a custom field Is_Overdue__c (Checkbox) to true
Create a Task for the operations team assigned to the Order Owner
Send an alert email to the Order Owner


Before You Start — Four Questions
Question 1
The pipeline has 4 steps — each step depends on the previous one completing successfully. You built a 3-step chain in Week 3 Day 3 (Order Processing). The pattern is the same here.
Each step should be a separate Queueable job. But should you have 4 separate Queueable classes (one per step) or one Queueable class that knows which step to execute based on a parameter?
Think about maintainability — if you need to add a Step 5 later, which approach is easier to extend?

Question 2
Step 2 makes a callout to a mock payment gateway. Step 4 makes a callout to a mock shipping API. Both are in the same Queueable chain.
You know from Week 3 that @future cannot be chained and each Queueable execute() can only make callouts if it implements Database.AllowsCallouts. But here is a subtlety — can you make two callouts in the same execute() method? Or does each callout need its own separate transaction?

Question 3
For OverdueOrderBatch — it needs to create Tasks AND send emails AND update Order records. That is 3 different DML/email operations per batch chunk.
What is the correct order for these operations and why? Think about what happens if the Task creation succeeds but the email fails — should the Order still be marked as overdue?

Question 4
The overdue threshold (3 days) lives in Order_Config__mdt. The batch runs for potentially thousands of orders. Should it query Order_Config__mdt inside the execute() method (once per chunk) or in start() (once for the entire batch run)?*/