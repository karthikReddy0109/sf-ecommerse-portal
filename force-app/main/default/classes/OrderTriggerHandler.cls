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
}