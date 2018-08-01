// This is a utility class to help test HTTP callouts.
// Usage Notes:
//  * Can handle multiple mocks for each HTTP Method on multiple endpoints
//  * Once a mock is consumed, it will be removed so the next mock in line will run
//  * If there is only 1 mock remaining for any given Endpoint/Method combination, it will not be removed
//  * By default, incoming request will be mapped only using the base URL.  You can change this
//       behavoir if needed by setting ignoreQuery to true.
// See https://github.com/ChuckJonas/MockHttpResponseHandler for updates.
// v1.0
@isTest
global class MockHttpResponseHandler implements HttpCalloutMock {

    //Each endpoint gets a ResponseEndpointHandler that stores a list of responses for each method
    private Map<String,ResponseEndpointHolder> responseMap = new Map<String,ResponseEndpointHolder>();

    //This causes the ? query params to be ignored when routing responses
    public Boolean ignoreQuery {get; set;}

    public MockHttpResponseHandler(){
        ignoreQuery = true;
    }

    public void addResponse(String endpoint, IMockResponse response){
        if(ignoreQuery){
            endpoint = getBaseUrl(endpoint);
        }

        ResponseEndpointHolder holder;
        if(responseMap.containsKey(endpoint)){
            holder = responseMap.get(endpoint);
        }else{
            holder = new ResponseEndpointHolder();
            responseMap.put(endpoint, holder);
        }
        holder.addMockResponse(response);
    }

    global HTTPResponse respond(HTTPRequest req) {
        String endpoint = req.getEndpoint();
        if(ignoreQuery){
            endpoint = getBaseUrl(endpoint);
        }
        if(!responseMap.containsKey(endpoint)){
            throw new MockHttpHandlerException('No response for endpoint:' + endpoint);
        }
        ResponseEndpointHolder responseHolder = responseMap.get(endpoint);
        return responseHolder.getMockResponse(req);
    }

    private String getBaseUrl(String endpoint){
        Url baseUrl = new URL(endpoint);
        return baseUrl.getHost() + baseUrl.getPath();
    }



//=== INNER CLASSES ===

    //Interface used for MockReponses.
    //  Implement this if you need a specialized Mock Response
    public interface IMockResponse{
        HTTPResponse getResponse(HTTPRequest req);
        String getMethod();
    }

    //Base class that covers most simple use cases
    public virtual class SimpleMockResponse implements IMockResponse{
        private String method;
        public String getMethod(){
            return method;
        }

        public void setMethod(String value){
            this.method = value;
        }

        public String contentType { get; set;}

        public Integer statusCode {get; set;}

        public Map<String, String> headers {get; set;}

        public String body {get; set;}

        public SimpleMockResponse(String method, String body){
            this.method = method;
            this.body = body;

            this.headers = new Map<String, String>();

            //defaults
            this.statusCode = 200;
            this.contentType = 'application/json';
        }

        public HTTPResponse getResponse(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', contentType);
            if(this.body != null){
                res.setBody(body);
            }
            res.setStatusCode(statusCode);
            for(String key : headers.keySet()){
                res.setHeader(key, headers.get(key));
            }

            return res;
        }
    }


    //Endpoint Handler is used to store a list of reponses for each HTTP method on an endpoint
    private class ResponseEndpointHolder{
        protected Map<String, List<IMockResponse>> endpointMethodMap = new Map<String, List<IMockResponse>>();

        public HTTPResponse getMockResponse(HTTPRequest req){
            String method = req.getMethod();
            List<IMockResponse> responses = endpointMethodMap.get(method);
            if(responses == null || responses.size() == 0){
                throw new MockHttpHandlerException('No response for method:' + method);
            }else if(responses.size() == 1){
                return responses[0].getResponse(req);
            }else{
                return responses.remove(0).getResponse(req);
            }
            return null;
        }

        public void addMockResponse(IMockResponse response){
            String method = response.getMethod();
            if(method == null){
                throw new MockHttpHandlerException('Method cannot be null!');
            }

            if(endpointMethodMap.containsKey(method)){
                endpointMethodMap.get(method).add(response);
            }else{
                endpointMethodMap.put(method, new List<IMockResponse>{ response });
            }
        }
    }

    public class MockHttpHandlerException extends Exception {}


//=== TESTS ===
    @isTest static void testHttpMockHandler() {
        String url1 = 'http://test.com';
        String url2 = 'http://test2.com';

        MockHttpResponseHandler mock = new MockHttpResponseHandler();

        //going to run this one twice...
        MockHttpResponseHandler.SimpleMockResponse m1 =
                new MockHttpResponseHandler.SimpleMockResponse('GET', 'get1');
        MockHttpResponseHandler.SimpleMockResponse m2 =
                new MockHttpResponseHandler.SimpleMockResponse('GET', 'get2');
        MockHttpResponseHandler.SimpleMockResponse m3 =
                new MockHttpResponseHandler.SimpleMockResponse('POST', 'post1');

        //test multiple items on single method
        mock.addResponse(url1, m1);
        mock.addResponse(url1, m1);
        mock.addResponse(url1, m2);
        //test multiple methods
        mock.addResponse(url1, m3);
        //test for multiple endpoints
        mock.addResponse(url2, m1);


        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);

        //assert on GETS
        //  get1 should show up twice, then get 2 should show on every additional call
        System.assertEquals('get1', sendRequest('GET', url1));
        //test that Query String is ignored
        System.assertEquals('get1', sendRequest('GET', url1 + '?foo=bar'));
        System.assertEquals('get2', sendRequest('GET', url1));
        System.assertEquals('get2', sendRequest('GET', url1));
        //assert on post
        System.assertEquals('post1', sendRequest('POST', url1));
        //assert on second endpoint
        System.assertEquals('get1', sendRequest('GET', url2));
        Test.stopTest();

    }

    private static String sendRequest(String method, String endpoint){
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        Http http = new Http();
        HttpResponse response = http.send(req);
        return response.getBody();
    }

}