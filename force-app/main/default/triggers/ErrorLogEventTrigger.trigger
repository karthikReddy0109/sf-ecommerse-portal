trigger ErrorLogEventTrigger on Error_Log_Event__e (after insert) {
    ErrorLogEventTriggerHandler.insertErrorLog(Trigger.New);
}