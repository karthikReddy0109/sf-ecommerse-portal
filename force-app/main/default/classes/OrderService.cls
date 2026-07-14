public with sharing class OrderService {

    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        'Draft'      => new Set<String>{'Confirmed', 'Cancelled'},
        'Confirmed'  => new Set<String>{'Processing', 'Cancelled'},
        'Processing' => new Set<String>{'Shipped', 'Cancelled'},
        'Shipped'    => new Set<String>{'Delivered'},
        'Delivered'  => new Set<String>(),
        'Cancelled'  => new Set<String>()
    };

    private static final Map<String, String> STATUS_TO_PROCESSING_STAGE = new Map<String, String>{
        'Confirmed' => 'Validated',
        'Processing' => 'Payment Confirmed',
        'Shipped' => 'Shipped',
        'Delivered' => 'Fulfilled',
        'Cancelled' => ''
    };

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

    public static Id updateOrderStatus(Id orderId, String newStatus){
        List<Order__c> orders = [SELECT Id, Status__c, Processing_Stage__c FROM Order__c WHERE Id = :orderId LIMIT 1];
        if(orders.isEmpty()){
            throw new CustomExceptions.RecordNotFoundException('Order not found: ' + orderId);
        }
        Order__c order = orders[0];
        String currStatus = order.Status__c;
        Set<String> allowedStatuses = VALID_TRANSITIONS.get(currStatus);
        if(allowedStatuses == null || !allowedStatuses.contains(newStatus)){
            throw new CustomExceptions.ValidationException(
                currStatus + ' cannot be transitioned to ' + newStatus
            );
        }
        if(!VALID_TRANSITIONS.get(currStatus).contains(newStatus)){
            throw new CustomExceptions.ValidationException(currStatus + ' cannot be transitioned to ' + newStatus);
        }
        order.Status__c = newStatus;
        order.Processing_Stage__c = STATUS_TO_PROCESSING_STAGE.containsKey(order.Status__c) ? STATUS_TO_PROCESSING_STAGE.get(order.Status__c) : order.Processing_Stage__c;
        try{
            update order;
        }catch(Exception e){
            System.debug('An error occured while updating order : ' + orderId);
        }
    
        return orderId;
    }

    private static void deductStock(List<OrderLineItem> lineItems){
        Set<Id> productIdSet = new Set<Id>();
        for(OrderLineItem item : lineItems){
            if(item.productId == null) continue;
            productIdSet.add(item.productId);
        }
        Map<Id, Product__c> productIdToProductMap = new Map<Id, Product__c>(
            [
                SELECT Id, Stock_Quantity__c
                FROM Product__c
                WHERE Id IN: productIdSet
                FOR UPDATE
            ]
        );
        List<Product__c> productsToUpdate = new List<Product__c>();
        for(OrderLineItem item : lineItems){
            if(item.productId == null || !(productIdToProductMap.containsKey(item.productId))) continue;
            Product__c product = new Product__c(Id = item.productId);
            Decimal currStock = productIdToProductMap.get(item.productId).Stock_Quantity__c == null ? 0 : productIdToProductMap.get(item.productId).Stock_Quantity__c;
            if(currStock < item.quantity) {
                throw new CustomExceptions.ValidationException(
                    'Insufficient stock for product: ' + item.productId + 
                    '. Available: ' + currStock + ', Requested: ' + item.quantity
                );
            }
            product.Stock_Quantity__c = currStock - item.quantity;
            productsToUpdate.add(product);
        }
        if(!productsToUpdate.isEmpty()){
            try{
                update productsToUpdate;
            }catch(Exception e){
                throw new AuraHandledException('An exception occured while updating product records : ' + e.getMessage());
            }
        }
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
            System.debug('An error occured while insrting order ' + e.getMessage());
        }
        return order.Id;
    }

    @AuraEnabled
    public static Id createOrder(OrderCreateRequest request){
        try{
            // Stage 1 — validate stock and get product map
            Map<Id, Product__c> productMap = validateStockAvailability(request.lineItems);
            
            // Stage 2 — create order and line items
            Id orderId = insertOrderWithLineItems(request, productMap);
            
            // Stage 3 — deduct stock
            //deductStock(request.lineItems);
            
            return orderId;
            
        } catch(CustomExceptions.ValidationException e){
            throw new AuraHandledException(e.getMessage());
        } catch(Exception e){
            //ErrorLogger.log(e, 'OrderService', 'createOrder', null, 'ERROR');
            throw new AuraHandledException('Order creation failed: ' + e.getMessage());
        }
    }

    private static void releaseStock(Id orderId){
        // 1. Retrieve order line items for the order
        List<Order_Line_Item__c> orderLineItems = [
            SELECT Id, Product__c, Quantity__c
            FROM Order_Line_Item__c
            WHERE Order__c =: orderId
        ];
        if(orderLineItems.isEmpty()) return;
        // 2. Get products for those order line items
        Set<Id> productIdSet = new Set<Id>();
        for(Order_Line_Item__c item : orderLineItems){
            if(item.Product__c == null) continue;
            productIdSet.add(item.Product__c);
        }
        Map<Id, Product__c> idToProductMap = new Map<Id, Product__c>
            (
                [
                    SELECT Id, Stock_Quantity__c
                    FROM Product__c 
                    WHERE Id IN: productIdSet
                    FOR UPDATE
                ]
            );
        // 3. Update stock quantity
        List<Product__c> productsToUpdate = new List<Product__c>();
        for(Order_Line_Item__c item : orderLineItems){
            if(idToProductMap.containsKey(item.Product__c)){
                Decimal stockQty = idToProductMap.get(item.Product__c).Stock_Quantity__c;
                Decimal updatedQty = stockQty == null ? item.Quantity__c : stockQty + item.Quantity__c;
                Product__c product = new Product__c(
                    Id = item.Product__c,
                    Stock_Quantity__c = updatedQty
                );
                productsToUpdate.add(product);
            }
        }
        if(!productsToUpdate.isEmpty()){
            try{
                update productsToUpdate;
            }catch(Exception e){
                System.debug('An error occured while releasing stock ' + e.getMessage());
            }
        }
    }

    @AuraEnabled
    public static Id cancelOrder(Id orderId){
        // 1. Fetch the order with Status, Payment Status & Final Amount
        try{
            List<Order__c> orderList = [
                SELECT Status__c, Payment_Status__c, Final_Amount__c, Processing_Stage__c
                FROM Order__c
                WHERE Id =: orderId
                LIMIT 1 
            ];
            if(orderList.isEmpty()){
                throw new CustomExceptions.RecordNotFoundException('Order not found: ' + orderId);
            }
            Order__c order = orderList[0];
            // 2. Validate if order can be cancelled. Only orders not in DELIVERED and CANCELLED state can be cancelled.
            if(order.Status__c == 'Delivered' || order.Status__c == 'Cancelled'){
                throw new CustomExceptions.ValidationException('Order cannot be cancelled since the order status is : ' + order.Status__c);
            }
            // 3. Release stock back to products
            if(order.Processing_Stage__c == 'Fulfilled' || order.Processing_Stage__c == 'Shipped'){
                releaseStock(orderId);
            }
            // 4. If payment Status is paid then create a Refund record
            if(order.Payment_Status__c == 'Paid'){
                Refund__c refund = new Refund__c(
                    Order__c = orderId,
                    Amount__c = order.Final_Amount__c,
                    Reason__c = 'Other'
                );
                insert refund;
            }
            // 5. Update order to cancelled.
            order.Status__c = 'Cancelled';
            update order;
            // 6. return the orderId.
            
        }catch(Exception e){
            System.debug('An error occured while cancelling order with orderId : ' + orderId);
        }
        return orderId;
    }

    @AuraEnabled(cacheable = true)
    public static List<Map<String, String>> getValidNextStatuses(String currentStatus){
        List<Map<String, String>> options = new List<Map<String, String>>();
        Set<String> validStatuses = VALID_TRANSITIONS.get(currentStatus);
        if(validStatuses == null) return options;
        for(String status : validStatuses){
            options.add(new Map<String, String>{
                'label' => status,
                'value' => status
            });
        }
        return options;
    }

    public class GetOrdersWrapper{
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String customerId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String contactId;
        @AuraEnabled public String status;
        @AuraEnabled public String paymentStaus;
        @AuraEnabled public Decimal finalAmount;
        @AuraEnabled public Date orderDate;
        @AuraEnabled public String shippingAddress;
        @AuraEnabled public String trackingNumber;
        @AuraEnabled public Date expectedDeliveryDate;
        @AuraEnabled public String notes;
        @AuraEnabled public String processingStage;
    }

    @AuraEnabled(cacheable = true)
    public static List<GetOrdersWrapper> getOrders(String status, String paymentStatus, String fromDate, String toDate){
        String queryString = 'SELECT Id, Name, Customer__c, Customer__r.Name, Contact__c, Status__c, Payment_Status__c, Final_Amount__c, Order_Date__c, Shipping_Address__c, Tracking_Number__c, Expected_Delivery__c, Notes__c, Processing_Stage__c FROM Order__c';
        if(status != null && !String.isBlank(status)){
            queryString += ' WHERE Status__c =: status';
        }
        if(!String.isBlank(fromDate)){
            Date formattedFromDate = Date.valueOf(fromDate);
            queryString += ' AND Order_Date__c >= :formattedFromDate';
        }
        if(!String.isBlank(toDate)){
            Date formattedToDate = Date.valueOf(toDate);
            queryString += ' AND Order_Date__c <= :formattedToDate';
        }
        if(!String.isBlank(paymentStatus)){
            queryString += ' AND Payment_Status__c =: paymentStatus';
        }
        queryString += ' ORDER BY :Order_Date__c DESC';
        List<GetOrdersWrapper> ordersWrapper = new List<GetOrdersWrapper>();
        try{
            List<Order__c> orderList = Database.query(queryString);
            for(Order__c order : orderList){
                GetOrdersWrapper orderWrapperItem = new GetOrdersWrapper();
                orderWrapperItem.id = order.Id;
                orderWrapperItem.name = order.Name;
                orderWrapperItem.customerId = order.Customer__c;
                orderWrapperItem.customerName = order.Customer__r.Name;
                orderWrapperItem.expectedDeliveryDate = order.Expected_Delivery__c;
                orderWrapperItem.contactId = order.Contact__c;
                orderWrapperItem.finalAmount = order.Final_Amount__c;
                orderWrapperItem.notes = order.Notes__c;
                orderWrapperItem.orderDate = order.Order_Date__c;
                orderWrapperItem.paymentStaus = order.Payment_Status__c;
                orderWrapperItem.status = order.Status__c;
                orderWrapperItem.shippingAddress = order.Shipping_Address__c;
                orderWrapperItem.trackingNumber = order.Tracking_Number__c;
                ordersWrapper.add(orderWrapperItem);
            }
        }catch(Exception e){
            System.debug('An exception occured while querying orders');
        }
        return ordersWrapper;
    }
}