*** Settings ***
Documentation     Simple API Authentication Test Suite for vKho API Tests login and authentication endpoints
Library           RequestsLibrary    # Make sure this is installed
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}        https://api.vkho.net
${USERNAME}        huynh22.manager
${PASSWORD}        Snowfox1991
${RESULTS_DIR}     ${CURDIR}${/}results

*** Test Cases ***
User Should Be Able To Login
    [Documentation]    Verify that a user can successfully login and receive a token
    [Tags]    authentication    login    positive
    # Create session
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${body}=       Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
    # Send login request
    Create Session    vkho    ${BASE_URL}    verify=True    disable_warnings=True
    ${response}=    POST On Session    
    ...    vkho    
    ...    /auth/login    
    ...    json=${body}    
    ...    headers=${headers}    
    ...    expected_status=201
    
    # Verify response
    Log    ${response.text}
    ${json}=    Evaluate    json.loads('''${response.text}''')    json
    
    # Validate response contains expected fields
    Dictionary Should Contain Key    ${json}    access_token
    
    # Save response for later tests
    Set Suite Variable    ${ACCESS_TOKEN}    ${json}[access_token]
    
    # Save response to file
    Create Directory    ${RESULTS_DIR}
    ${timestamp}=    Evaluate    int(round(time.time() * 1000))    time
    Create File    ${RESULTS_DIR}${/}login_response_${timestamp}.json    ${response.text}
    
    # Logging
    Log    Login successful. Token: Bearer ${ACCESS_TOKEN}

User Authentication Should Be Validated With Valid Token
    [Documentation]    Verify that a user can access protected resources with a valid token
    [Tags]    authentication    positive
    Should Not Be Empty    ${ACCESS_TOKEN}    msg=No authentication token available. Run login test first.
    
    # Prepare request with auth token
    ${headers}=    Create Dictionary    
    ...    Authorization=Bearer ${ACCESS_TOKEN}
    ...    Content-Type=application/json
    
    # Send authentication request
    ${response}=    GET On Session    
    ...    vkho    
    ...    /auth/authenticate    
    ...    headers=${headers}    
    ...    expected_status=200
    
    # Verify response
    Should Not Be Empty    ${response.text}
    
    # Save response to file
    ${timestamp}=    Evaluate    int(round(time.time() * 1000))    time
    Create File    ${RESULTS_DIR}${/}auth_response_${timestamp}.json    ${response.text}
    
    # Logging
    Log    Authentication successful
    Log    Response: ${response.text}

User Authentication Should Fail With Invalid Token
    [Documentation]    Verify that authentication fails with an invalid token
    [Tags]    authentication    negative
    
    # Create a new session for invalid auth
    Create Session    vkho_invalid    ${BASE_URL}    verify=True    disable_warnings=True
    
    # Prepare request with invalid token
    ${headers}=    Create Dictionary    
    ...    Authorization=Bearer InvalidToken123
    ...    Content-Type=application/json
    
    # Send authentication request (expect to fail)
    Run Keyword And Expect Error    *    GET On Session    
    ...    vkho_invalid    
    ...    /auth/authenticate    
    ...    headers=${headers}
    
    # Logging
    Log    Authentication failed as expected with invalid token
    
User Should Not Be Able To Login With Invalid Credentials
    [Documentation]    Verify that login fails with invalid credentials
    [Tags]    authentication    login    negative
    
    # Create session
    Create Session    vkho_negative    ${BASE_URL}    verify=True    disable_warnings=True
    
    # Prepare request with invalid credentials
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${body}=       Create Dictionary    username=invalid_user    password=invalid_password
    
    # Send login request (expect to fail)
    Run Keyword And Expect Error    *    POST On Session    
    ...    vkho_negative    
    ...    /auth/login    
    ...    json=${body}    
    ...    headers=${headers}
    
    # Logging
    Log    Login failed as expected with invalid credentials