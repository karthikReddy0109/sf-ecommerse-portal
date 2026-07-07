public with sharing class productService {
    private static String getStockStatus(Decimal stockQty, Decimal restockThreshold){
        if(stockQty == 0){
            return 'Out of Stock';
        } 
        else if(stockQty > 0 && stockQty <= restockThreshold){
            return 'Low Stock';
        }
        return 'In Stock';
    }
    @AuraEnabled(cacheable = true)
    public static List<Product__c> searchProducts(String searchTerm, String category, String stockStatus){
        String likeParam = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        String searchString = 'SELECT Id, Category__c, Stock_Quantity__c, Name, Restock_Threshold__c FROM Product__c WHERE Is_Active__c = true';
        if(!String.isBlank(searchTerm)){
            searchString += ' AND(Name LIKE :likeParam OR Description__c LIKE :likeParam)';
        }
        if(!String.isBlank(category)){
            searchString += ' AND Category__c =: category';
        }
        List<Product__c> products;
        try{
            products = Database.query(searchString);
        }catch(QueryException qe){
            String errorMessage = qe.getMessage();
            System.debug('SOQL Query Failed: ' + errorMessage);
            throw new AuraHandledException('Search failed : ' + errorMessage);
        }
        List<Product__c> filteredProducts = new List<Product__c>();
        for(Product__c product : products){
            if(String.isBlank(stockStatus)){
                filteredProducts.add(product);
                continue;
            }
            if(product.Stock_Quantity__c != null){
                String productStockStatus = getStockStatus(product.Stock_Quantity__c, product.Restock_Threshold__c);
                if(productStockStatus == stockStatus){
                    filteredProducts.add(product);
                }
            }
        }
        return filteredProducts;
    }

    @AuraEnabled(cacheable = true)
    public static Boolean checkStockAvailability(Id productId, Integer requestedQuantity){
        List<Product__c> products = [
            SELECT Id, Stock_Quantity__c
            FROM Product__c
            WHERE Id =: productId
            LIMIT 1
        ];
        if(products[0].Stock_Quantity__c >= requestedQuantity) return true;
        return false;
    }

    @AuraEnabled(cacheable = true)
    public static Product__c getProductById(Id productId){
        try{
            List<Product__c> products = [
                SELECT Name, Category__c, Cost_Price__c, Description__c, Is_Active__c,
                Product_Code__c, Restock_Status__c, Restock_Threshold__c, Stock_Quantity__c, Total_Revenue__c, Unit_Price__c
                FROM Product__c
                WHERE Id =: productId
            ];
            if(products.isEmpty()){
                throw new CustomExceptions.RecordNotFoundException('Product not found');
            }
            return products[0];
        }catch(CustomExceptions.RecordNotFoundException rnf){
            System.debug('Error: ' + rnf.getMessage());
            throw new AuraHandledException(rnf.getMessage());
        }catch(Exception e){
            System.debug('Generic exception ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}