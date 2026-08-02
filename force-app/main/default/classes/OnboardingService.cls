public with sharing class OnboardingService {
    @InvocableMethod(label = 'Send Welocme Email' description = 'Sends welcome email to newly onboarded contact')
    public static void sendWelcomeEmail(List<WelcomeEmailRequest> requests){
        List<Messaging.SingleEmailMessage> mailList = new List<Messaging.SingleEmailMessage>();
        for(WelcomeEmailRequest emailRequest : requests){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setSubject('Welcome to SF-Commerce, ' + emailRequest.accountName);
            mail.setPlainTextBody('Contact is connected to account : ' + emailRequest.accountName);
            mail.setTargetObjectId(emailRequest.contactId);
            mailList.add(mail);
        }
        try{
            if(!mailList.isEmpty()){
                Messaging.sendEmail(mailList);
            }
        }catch(Exception e){
            ErrorLogger.logError('OnboardingService', 'sendWelcomeEmail', e);
        }
    }

    public class WelcomeEmailRequest{
        @InvocableVariable(required = true)
        public Id contactId;

        @InvocableVariable
        public String accountName;

        @InvocableVariable
        public String contactEmail;
    }
}