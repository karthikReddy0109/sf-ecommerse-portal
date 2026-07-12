public with sharing class ShipmentServiceQueueable implements Queueable, Database.AllowsCallouts{
    Set<Id> fulfilledOrderIds;
    public ShipmentServiceQueueable(Set<Id> fulfilledOrderIds) {
        this.fulfilledOrderIds = fulfilledOrderIds;
    }

    public class ShipmentResponse{
        public List<Shipment> shipments;
    }

    public class Shipment{
        public String shipmentId;
        public String trackingNumber;
        public String status;
        public Id orderId;
    }

    public class ShipmentPayload{
        List<OrderShipmentRequest> orders = new List<OrderShipmentRequest>();
    }

    public class OrderShipmentRequest {
        public String orderId;
        public String shippingAddress;
    }

    private HttpResponse makeCalloutToShipmentAPI(ShipmentPayload payload){
        HttpResponse response = HttpService.doPost('https://webhook.site/08f9f63c-2df6-4bac-99f5-04119a232f43', JSON.serialize(payload));
        return response;
    }

    private void createShipmentRecord(ShipmentResponse shipmentResponse){
        List<Shipment__c> shipmentRecords = new List<Shipment__c>();
        for(Shipment shipment : shipmentResponse.shipments){
            shipmentRecords.add(new Shipment__c(
                Order__c = shipment.orderId,
                Tracking_Number__c = shipment.trackingNumber,
                Carrier__c = 'Mock Carrier',
                Status__c = 'Pending'
            ));
        }
        if(!shipmentRecords.isEmpty()){
            insert shipmentRecords;
        }
    }

    public void execute(QueueableContext qc){
        List<Order__c> orderList = [
            SELECT Id, Name, Shipping_Address__c
            FROM Order__c 
            WHERE Id IN: fulfilledOrderIds
        ];
        ShipmentPayload payload = new ShipmentPayload();
        for(Order__c order : orderList){
            OrderShipmentRequest ord = new OrderShipmentRequest();
            ord.orderId = order.Id;
            ord.shippingAddress = order.Shipping_Address__c;
            payload.orders.add(ord);
        }
        HttpResponse response = makeCalloutToShipmentAPI(payload);
        if(response.getStatusCode() == 200){
            ShipmentResponse responseWrapper = (ShipmentResponse) JSON.deserialize(
                response.getBody(), ShipmentResponse.class
            );
            createShipmentRecord(responseWrapper);

            // Update order status and tracking numbers
            List<Order__c> ordersToUpdate = new List<Order__c>();
            for(Shipment shipment : responseWrapper.shipments){
                ordersToUpdate.add(new Order__c(
                    Id = shipment.orderId,
                    Status__c = 'Shipped',
                    Processing_Stage__c = 'Shipped',
                    Tracking_Number__c = shipment.trackingNumber
                ));
            }
            if(!ordersToUpdate.isEmpty()){
                update ordersToUpdate;
            }
        } else {
            // Mark orders as failed
            List<Order__c> failedOrders = new List<Order__c>();
            for(Id orderId : fulfilledOrderIds){
                failedOrders.add(new Order__c(
                    Id = orderId,
                    Status__c = 'Failed',
                    Notes__c = 'Shipping API failed: ' + response.getBody()
                ));
            }
            if(!failedOrders.isEmpty()) update failedOrders;
        }
    }
}