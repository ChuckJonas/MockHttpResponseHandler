# MockHttpResponseHandler

An Apex a utility class to help test HTTP callouts (Salesforce)

## Install

1. `git clone`
1. `cd` into folder
1. `sfdx force:mdapi:deploy -d ./src -w 10000 -u [username]`

## Usage

### SimpleMockResponse

While you can define your own response classes to respond in pretty much anyway you need, the `MockHttpResponseHandler.SimpleMockResponse` will handle most use cases.

#### Example GET, POST & Error

```java
@isTest static void calloutTest() {
    String testEndpoint = 'http://example-api.com';
    String getResponse = 'hello world';
    String postResponse = '<xml><title>hello world</title></xml>';

    //successful GET which return data in body
    MockHttpResponseHandler.SimpleMockResponse getResp = new MockHttpResponseHandler.SimpleMockResponse('GET', getResponse);

    //successful POST which return data in body.  Can change contentType
    MockHttpResponseHandler.SimpleMockResponse postResp = new MockHttpResponseHandler.SimpleMockResponse('POST', postResponse);
    postResp.contentType = 'application/xml';

    //can set other status codes to test failures
    String errorEndpoint = testEndpoint + '/error';
    MockHttpResponseHandler.SimpleMockResponse errResp = new MockHttpResponseHandler.SimpleMockResponse('GET', null);
    errResp.statusCode = 500;

    MockHttpResponseHandler mock = new MockHttpResponseHandler();
    mock.addResponse(testEndpoint, getResp);
    mock.addResponse(testEndpoint, postResp);
    mock.addResponse(errorEndpoint, errResp);

    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
        Http http = new Http();
        //send get
        HttpRequest req = new HttpRequest();
        req.setEndpoint(testEndpoint);
        req.setMethod('GET');

        HTTPResponse res = http.send(req);
        System.assertEquals(getResponse, res.getBody());

        //send post
        req = new HttpRequest();
        req.setEndpoint(testEndpoint);
        req.setMethod('POST');

        res = http.send(req);
        System.assertEquals(postResponse, res.getBody());

        //send error
        req = new HttpRequest();
        req.setEndpoint(errorEndpoint);
        req.setMethod('GET');

        res = http.send(req);
        System.assertEquals(500, res.getStatusCode());

    Test.stopTest();
}
```

#### Same Request, Different Responses

If you need to call the same method & endpoint multiple times but return different responses, you have a two options:

1. Implement your own `IMockResponse` which looks at the request data and responds via some logic.  This is best if you don't know how many times the endpoint may be called.
1. Add multiple instances to with same HTTP operation to an Endpoint using `addResponse`.  When you do this, each instance will be returned in the order that you add them.  If there is only 1 instance remaining in the queue, it will continue to return this response indefinitely.

```java

    MockHttpResponseHandler.SimpleMockResponse getResp = new MockHttpResponseHandler.SimpleMockResponse('GET', getResponse);

    MockHttpResponseHandler.SimpleMockResponse errResp = new MockHttpResponseHandler.SimpleMockResponse('GET', null);
    errResp.statusCode = 500;

    MockHttpResponseHandler mock = new MockHttpResponseHandler();
    mock.addResponse(testEndpoint, getResp);
    mock.addResponse(testEndpoint, getResp);
    mock.addResponse(testEndpoint, errResp);

    // when hitting GET:testEndpoint, 'getResp' will be returned twice.  All additional calls will return 'errResp'
```

#### Ignoring Query String


By default, query strings are ignored.  EG if you `addResponse('http://example.com', resp)`, it will return for `http://example.com?foo=1`.  If you want your response to target a specific query string, you can do so by setting `mock.ignoreQuery = false`.

***NOTE***: if you need more dynamic handling of query string, leave ignore `ignoreQuery=true` and implement your own `IMockResponse`.