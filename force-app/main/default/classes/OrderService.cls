public with sharing class OrderService {
    public class OrderCreateRequest{
        public Id customerId;
        public Id contactId;
        public String shippingAddress;
        public List<OrderLineItem> lineItems;
    }

    public class OrderLineItem{
        public Id productId;
        public Integer quantity;
        public Decimal discountPercent;
    }

    private static void validateStockAvailability(List<OrderLineItem> lineItems){
        // Collect product Id's 
        Set<Id> productIdSet = new Set<Id>();
        for(OrderLineItem item : lineItems){
            if(item.productId != null){
                productIdSet.add(item.productId);
            }
        }
        // Retrieve product along with quantity
        Map<Id, Product__c> productMap = new Map<Id, Product__c>(
            [
                SELECT Id, Stock_Quantity__c 
                FROM Product__c
                WHERE Id IN: productIdSet
            ]
        );
        // Check if quantity is available for each product
        List<String> productStockErrors = new List<String>();
        for(OrderLineItem item : lineItems){
            if(item.productId == null) continue;
            if(productMap.containsKey(item.productId)){
                Decimal availableStock = productMap.get(item.productId).Stock_Quantity__c;
                if(item.quantity > availableStock){
                    productStockErrors.add('Insufficient stock for product: ' + item.productId);
                }
            }
        }
        // Check if validation failed
        if(!productStockErrors.isEmpty()){
            // Throw custom exception
            throw new CustomExceptions.ValidationException('Stock not available for products : ' + String.join(productStockErrors, '\n'));
        }
    }

    public static Id createOrder(OrderCreateRequest request){

    }
}