public with sharing class PaymentGatewayService implements Queueable, Database.AllowsCallouts {
    Set<Id> orderIds = new Set<Id>(); 
    public PaymentGatewayService(Set<Id> orderIds) {
        this.orderIds = orderIds;
    }

    public class PaymentPayload{
        public Decimal amount;
        public String currencyCode = 'USD';
        public String paymentMethod = 'CreditCard';
        public String transactionId;
    }

    private Set<Id> makeCalloutToPaymentService(){
        List<Order__c> orders = [
            SELECT Id, Total_Amount__c, Name
            FROM Order__c 
            WHERE Id IN: orderIds
        ];
        List<Order__c> ordersToUpdate = new List<Order__c>();
        Set<Id> paymentConfirmedOrders = new Set<Id>();
        for(Order__c order : orders){
            PaymentPayload payload = new PaymentPayload();
            payload.amount = order.Total_Amount__c;
            payload.transactionId = order.Name;
            HttpResponse response = HttpService.doPost('https://webhook.site/08f9f63c-2df6-4bac-99f5-04119a232f43', JSON.serialize(payload));
            Order__c ord = new Order__c();
            ord.Id = order.Id;
            if(response.getStatusCode() == 200){
                ord.Processing_Stage__c = 'Payment Confirmed';
                paymentConfirmedOrders.add(order.Id);
            }else{
                ord.Status__c = 'Failed';
            }
            ordersToUpdate.add(ord);
        }
        if(!ordersToUpdate.isEmpty()){
            update ordersToUpdate;
        }
        return paymentConfirmedOrders;
    }

    public void execute(QueueableContext qc){
        try{
            Set<Id> successfullOrders = makeCalloutToPaymentService();
            if(!successfullOrders.isEmpty()){
                System.enqueueJob(new OrderFulfillmentQueueable(successfullOrders));
            }
        }catch(Exception e){
            System.debug('An exception occured');
        }
    }
}