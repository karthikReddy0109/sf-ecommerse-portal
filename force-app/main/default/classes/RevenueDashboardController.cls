public with sharing class RevenueDashboardController {
    public class DashboardData{
        @AuraEnabled public Decimal todayRevenue;
        @AuraEnabled public Integer todayOrders;
        @AuraEnabled public Decimal monthRevenue;
        @AuraEnabled public Integer monthOrders;
        @AuraEnabled public Decimal quarterRevenue;
        @AuraEnabled public Integer quarterOrders;
        @AuraEnabled public Decimal yearRevenue;
        @AuraEnabled public Integer yearOrders;
        @AuraEnabled public List<MonthlyRevenue> revenueTrend;
        @AuraEnabled public List<StatusCount> ordersByStatus;
        @AuraEnabled public List<ProductRevenue> topProducts;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
    }
    public class MonthlyRevenue{
        public String monthLabel;
        public Decimal revenue;
    }
    public class StatusCount{
        public String status;
        public Integer count;
    }
    public class ProductRevenue{
        public String productName;
        public Decimal revenue;
    }
    @AuraEnabled(cacheable = true)
    public static DashboardData getDashboardData(){
        DashboardData data = new DashboardData();
        try{
            AggregateResult todaysData = setTodaysData();
            data.todayOrders = (Integer)todaysData.get('totalOrders');
            data.todayRevenue = todaysData.get('totalAmount') == null ? 0 : (Decimal)todaysData.get('totalAmount');
            AggregateResult monthlyData = getThisMonthsData();
            data.monthOrders = (Integer)monthlyData.get('totalOrders');
            data.monthRevenue = monthlyData.get('totalAmount') != null ? (Decimal)monthlyData.get('totalAmount') : 0;
            AggregateResult quarterlyData = getThisQuarterData();
            data.quarterOrders = (Integer)quarterlyData.get('totalOrders');
            data.quarterRevenue = quarterlyData.get('totalAmount') != null ? (Decimal)quarterlyData.get('totalAmount') : 0;
            AggregateResult yearlyData = getThisYearData();
            data.yearOrders = (Integer)yearlyData.get('totalOrders');
            data.yearRevenue = yearlyData.get('totalAmount') != null ? (Decimal)yearlyData.get('totalAmount') : 0;
            List<StatusCount> statusCountList = getOrdersByStatus();
            data.ordersByStatus = statusCountList;
            data.topProducts = getTopProducts();
            data.revenueTrend = getRevenueTrend();
            data.isSuccess = true;
        }catch(Exception e){
            data.isSuccess = false;
            data.errorMessage = e.getMessage();
        }
        
        return data;
    }

    private static AggregateResult setTodaysData(){
        AggregateResult ar = [
            SELECT COUNT(Id) totalOrders, SUM(Final_Amount__c) totalAmount
            FROM Order__c
            WHERE Order_Date__c = TODAY
            AND Status__c != 'Cancelled'
        ];
        return ar;
    }

    private static AggregateResult getThisMonthsData(){
        return [
            SELECT COUNT(Id) totalOrders, SUM(Final_Amount__c) totalAmount
            FROM Order__c
            WHERE Order_Date__c = THIS_MONTH AND Status__c != 'Cancelled'
        ];
    }

    private static AggregateResult getThisQuarterData(){
        return [
            SELECT COUNT(Id) totalOrders, SUM(Final_Amount__c) totalAmount
            FROM Order__c
            WHERE Order_Date__c = THIS_QUARTER AND Status__c != 'Cancelled'
        ];
    }

    private static AggregateResult getThisYearData(){
        return [
            SELECT COUNT(Id) totalOrders, SUM(Final_Amount__c) totalAmount
            FROM Order__c
            WHERE Order_Date__c = THIS_YEAR AND Status__c != 'Cancelled'
        ];
    }

    private static List<StatusCount> getOrdersByStatus(){
        List<StatusCount> statusCountList = new List<StatusCount>();
        for(AggregateResult ar : [
            SELECT Status__c, COUNT(Id) total
            FROM Order__c
            GROUP BY Status__c
        ]){
            StatusCount sc = new StatusCount();
            sc.count = (Integer)ar.get('total');
            sc.status = (String)ar.get('Status__c');
            statusCountList.add(sc);
        }
        return statusCountList;
    }

    private static List<ProductRevenue> getTopProducts(){
        List<ProductRevenue> productRevenueList = new List<ProductRevenue>();
        for(AggregateResult ar : [SELECT Product__r.Name, SUM(Line_Total__c) totalRevenue
        FROM Order_Line_Item__c
        WHERE Order__r.Status__c = 'Delivered'
        GROUP BY Product__r.Name
        ORDER BY SUM(Line_Total__c) DESC
        LIMIT 5]){
            ProductRevenue productRev = new ProductRevenue();
            productRev.productName = (String)ar.get('Product__r.Name');
            productRev.revenue = (Decimal)ar.get('totalRevenue');
            productRevenueList.add(productRev);
        }
        return productRevenueList;
    }

    private static List<MonthlyRevenue> getRevenueTrend(){
        List<MonthlyRevenue> monthlyRevenueList = new List<MonthlyRevenue>();
        String[] monthLabels = new String[]{
            'Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'
        };
        for(AggregateResult ar : [
            SELECT CALENDAR_MONTH(Order_Date__c) month,
                CALENDAR_YEAR(Order_Date__c) year,
                SUM(Final_Amount__c) revenue
            FROM Order__c
            WHERE Order_Date__c = LAST_N_MONTHS:6
            AND Status__c != 'Cancelled'
            GROUP BY CALENDAR_MONTH(Order_Date__c), CALENDAR_YEAR(Order_Date__c)
            ORDER BY CALENDAR_YEAR(Order_Date__c), CALENDAR_MONTH(Order_Date__c)            
        ]){
            MonthlyRevenue monthlyRev = new MonthlyRevenue();
            monthlyRev.monthLabel = monthLabels[(Integer)ar.get('month') - 1];
            monthlyRev.revenue = (Decimal)ar.get('revenue');
            monthlyRevenueList.add(monthlyRev);
        }
        return monthlyRevenueList;
    }
}