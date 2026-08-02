public with sharing class ErrorLogEventTriggerHandler {
    public static void insertErrorLog(List<Error_Log_Event__e> errorLogEvents){
        List<Error_Log__c> errorLogsToInsert = new List<Error_Log__c>();
        for(Error_Log_Event__e log : errorLogEvents){
            Error_Log__c errorLog = new Error_Log__c(
                Class_Name__c = log.Class_Name__c,
                Method_Name__c = log.Method_Name__c,
                Error_Description__c = log.Exception_Message__c
            );
            errorLogsToInsert.add(errorLog);
        }
        if(!errorLogsToInsert.isEmpty()){
            try{
                insert errorLogsToInsert;
            }catch(Exception e){
                System.debug('Error logging failed');
            }
        }
    }
}