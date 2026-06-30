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

    private static Map<Id, Product__c> validateStockAvailability(List<OrderLineItem> lineItems){
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
                SELECT Id, Stock_Quantity__c, Unit_Price__c
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
            }else{
                productStockErrors.add('Product not found : ' + item.productId);
            }
        }
        // Check if validation failed
        if(!productStockErrors.isEmpty()){
            // Throw custom exception
            throw new CustomExceptions.ValidationException('Stock not available for products : ' + String.join(productStockErrors, '\n'));
        }

        return productMap;
    }

    public static Id insertOrderWithLineItems(OrderCreateRequest request, Map<Id, Product__c> productMap){
        Order__c order = new Order__c();
        order.Status__c = 'Draft';
        order.Payment_Status__c = 'Pending';
        order.Order_Date__c = System.today();
        order.Customer__c = request.customerId;
        order.Contact__c = request.contactId;
        order.Shipping_Address__c = request.shippingAddress;

        try{
            insert order;
            List<Order_Line_Item__c> lineItemList = new List<Order_Line_Item__c>();
            for(OrderLineItem lineItem : request.lineItems){
                if(lineItem.productId == null) continue;
                Order_Line_Item__c ordLineItem = new Order_Line_Item__c();
                ordLineItem.Order__c = order.Id;
                ordLineItem.Product__c = lineItem.productId;
                ordLineItem.Quantity__c = lineItem.quantity;
                ordLineItem.Unit_Price__c =  productMap.get(lineItem.productId).Unit_Price__c;
                ordLineItem.Discount_Percent__c = lineItem.discountPercent;
                lineItemList.add(ordLineItem);
            }
            if(!lineItemList.isEmpty()){
                insert lineItemList;
            } 
        }catch(DmlException e){
            System.debug('An error occured while insrting order ' + e.getMessge());
        }
        return order.Id;
    }

    public static Id createOrder(OrderCreateRequest request){
        Map<Id, Product__c> productMap = validateStockAvailability(request.lineItems);
        Id orderId = insertOrderWithLineItems(request, productMap);
        return orderId;
    }
}