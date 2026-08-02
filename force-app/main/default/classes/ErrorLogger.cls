public with sharing class ErrorLogger {
    public static void logError(String className, String methodName, Exception e){
        Error_Log_Event__e errorLogEvent = new Error_Log_Event__e(
            Class_Name__c = className,
            Method_Name__c = methodName,
            Exception_Message__c = e.getMessage()
        );
        
        EventBus.publish(errorLogEvent);
    }
}