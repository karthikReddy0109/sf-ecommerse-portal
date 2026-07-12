// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

// Replace with actual Order Ids and Product Ids from debug logs above
// Replace with actual Order Ids
Id order1Id = 'a01fj00001RUjZJAA1';
Id order2Id = 'a01fj00001RUjZKAA1';

List<Shipment__c> shipments = new List<Shipment__c>{
    new Shipment__c(
        Order__c = order1Id,
        Tracking_Number__c = 'TRK-2026-001',
        Carrier__c = 'Blue Dart',
        Status__c = 'Delivered',
        Shipped_Date__c = Date.today().addDays(-8),
        Delivered_Date__c = Date.today().addDays(-6),
        Delivery_Notes__c = 'Delivered to reception'
    ),
    new Shipment__c(
        Order__c = order2Id,
        Tracking_Number__c = 'TRK-2026-002',
        Carrier__c = 'DHL',
        Status__c = 'In Transit',
        Shipped_Date__c = Date.today().addDays(-3),
        Delivery_Notes__c = 'In transit to destination'
    )
};
insert shipments;
System.debug('Shipments created: ' + shipments.size());