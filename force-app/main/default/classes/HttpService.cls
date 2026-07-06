public with sharing class HttpService {
    public static HttpResponse doGet(String namedCredentialPath){
        return sendRequest('GET', namedCredentialPath, null);
    }

    public static HttpResponse doPost(String namedCredentialPath, String jsonBody){
        return sendRequest('POST', namedCredentialPath, jsonBody);
    }

    private static HttpResponse sendRequest(String method, String path, String body){
        HttpRequest req = new HttpRequest();
        req.setEndpoint(path);
        req.setMethod(method);
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        if(body != null){
            req.setBody(body);
        }

        Http http = new Http();
        HttpResponse response;
        try{
            response = http.send(req);
            if(response.getStatusCode() >= 400){
                System.debug('HTTP Error Status: ' + response.getStatusCode() + ' - ' + response.getBody());
            }
        }catch(Exception e){
            System.debug('Callout Exception: ' + e.getMessage());
        }
        return response;
    }
}