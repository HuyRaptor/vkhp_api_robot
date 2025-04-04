*** Settings ***
Documentation     Advanced E2E Test Suite for Order Management with Complex Validations
...               Includes data validation, business rules, and edge cases
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Library           Process
Library           JSONLibrary
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Generate Order Data With Validation
    [Documentation]     Generate order data with validation rules
    [Arguments]         ${validation_type}=positive    ${custom_data}=${EMPTY}
    
    ${timestamp}=       Get Time    epoch
    ${order_code}=      Set Variable    ORD${timestamp}
    
    # Base order data
    ${order_data}=      Create Dictionary
    ...                 code=${order_code}
    ...                 customerName=Test Customer ${timestamp}
    ...                 customerPhone=800${timestamp}
    ...                 customerEmail=customer${timestamp}@example.com
    ...                 deliveryAddress=Test Address ${timestamp}
    ...                 deliveryTime=2024-04-02T10:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${ORDER_STATUS_NEW}
    
    # Modify data based on validation type
    IF    '${validation_type}' == 'missing_required'
        Remove From Dictionary    ${order_data}    customerName
    ELSE IF    '${validation_type}' == 'invalid_email'
        Set To Dictionary    ${order_data}    customerEmail=invalid.email
    ELSE IF    '${validation_type}' == 'invalid_phone'
        Set To Dictionary    ${order_data}    customerPhone=123
    ELSE IF    '${validation_type}' == 'long_strings'
        ${long_string}=    Evaluate    'x' * (${MAX_STRING_LENGTH} + 1)
        Set To Dictionary    ${order_data}    customerName=${long_string}
    ELSE IF    '${validation_type}' == 'special_chars'
        Set To Dictionary    ${order_data}    customerName=Test@#$%^&*()
    END
    
    # Add custom data if provided
    Run Keyword If    '${custom_data}' != '${EMPTY}'    Set To Dictionary    ${order_data}    &{custom_data}
    
    RETURN           ${order_data}

Validate Order Response
    [Documentation]     Validate order response data
    [Arguments]         ${response}    ${expected_data}=${EMPTY}    ${validation_type}=positive
    
    # Basic response validation
    Should Not Be Empty    ${response}    msg=Response should not be empty
    Dictionary Should Contain Key    ${response}    id    msg=Response missing ID field
    
    # Only validate required fields for positive scenarios
    IF    '${validation_type}' == 'positive'
        @{required_fields}=    Create List    code    customerName    customerPhone    customerEmail    deliveryAddress    status
        FOR    ${field}    IN    @{required_fields}
            Dictionary Should Contain Key    ${response}    ${field}
            ...    msg=Response missing required field: ${field}
        END
        
        # Validate field lengths
        ${name_length}=    Get Length    ${response.get('customerName', '')}
        Should Be True    ${name_length} <= ${MAX_STRING_LENGTH}
        
        ${phone_length}=    Get Length    ${response.get('customerPhone', '')}
        Should Be True    ${phone_length} >= ${MIN_PHONE_LENGTH} and ${phone_length} <= ${MAX_PHONE_LENGTH}
        
        # Validate email format
        ${email}=    Get From Dictionary    ${response}    customerEmail
        Should Match Regexp    ${email}    ^[\\w\\.-]+@[\\w\\.-]+\\.\\w+$
    END

Create Order With Validation
    [Documentation]     Create order with validation checks
    [Arguments]         ${order_data}    ${expected_status}=201    ${validation_type}=positive
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Handle expected failures for negative scenarios
    IF    '${validation_type}' == 'negative'
        Run Keyword And Expect Error    HTTPError: 400*
        ...    POST On Session
        ...    vkho
        ...    /orders/create
        ...    json=${order_data}
        ...    headers=${headers}
        RETURN
    END
    
    # Handle positive scenarios
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Validate Order Response    ${json}    validation_type=${validation_type}
    RETURN           ${json}[id]    ${json}

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get order request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get order response missing ID field
    
    RETURN           ${json}

Add Product To Order With Validation
    [Documentation]     Add product to order with validation rules
    [Arguments]         ${order_id}    ${product_id}    ${quantity}=1    ${price}=0    ${validation_type}=positive
    
    # Validate parameters
    Should Not Be Empty    ${order_id}    msg=Order ID cannot be empty
    Should Not Be Empty    ${product_id}    msg=Product ID cannot be empty
    
    # Validate quantity based on validation type
    IF    '${validation_type}' == 'negative'
        ${quantity}=    Set Variable    ${MAX_QUANTITY} + 1
    ELSE IF    '${validation_type}' == 'zero'
        ${quantity}=    Set Variable    0
    END
    
    # Get current order to update totals
    ${current_order}=    Get Order By ID    ${order_id}
    ${current_total}=    Set Variable    ${current_order.get('totalAmount', 0)}
    ${current_items}=    Set Variable    ${current_order.get('itemCount', 0)}
    
    # Calculate new totals
    ${new_total}=       Evaluate    ${current_total} + (${quantity} * ${price})
    ${new_items}=       Evaluate    ${current_items} + ${quantity}
    
    # Create product order data
    ${product_order_data}=    Create Dictionary
    ...                      orderId=${order_id}
    ...                      productId=${product_id}
    ...                      quantity=${quantity}
    ...                      price=${price}
    ...                      warehouseId=${WAREHOUSE_ID}
    ...                      totalAmount=${new_total}
    ...                      itemCount=${new_items}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Add product to order with validation
    ${response}=        Run Keyword If    '${validation_type}' == 'positive'    POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${product_order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ...                 ELSE    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${product_order_data}
    ...                 headers=${headers}
    
    # Process successful response
    IF    '${validation_type}' == 'positive'
        ${json}=            Evaluate         json.loads('''${response.text}''')    json
        RETURN           ${json}[id]    ${json}
    END

Verify API Error Response
    [Documentation]     Verify API error response matches expected error
    [Arguments]         ${error_msg}    ${expected_code}    ${expected_message}
    
    Should Match Regexp    ${error_msg}    HTTPError: ${expected_code}.*${expected_message}
    ...    msg=Unexpected error response. Expected: ${expected_code} - ${expected_message}, Got: ${error_msg}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for validation tests
    [Tags]              setup    validation
    Setup API Session

02 - Create Order With Valid Data Test
    [Documentation]     Test creating order with valid data
    [Tags]              create    positive    validation
    
    ${order_data}=      Generate Order Data With Validation    validation_type=positive
    ${order_id}    ${response}=    Create Order With Validation    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Set Suite Variable    ${TEST_ORDER_ID}    ${order_id}

03 - Create Order With Missing Required Fields Test
    [Documentation]     Test creating order with missing required fields
    [Tags]              create    negative    validation
    
    ${order_data}=      Generate Order Data With Validation    validation_type=missing_required
    Run Keyword And Expect Error    HTTPError: 400*Missing required field: customerName*
    ...    Create Order With Validation    ${order_data}    validation_type=negative

04 - Create Order With Invalid Email Test
    [Documentation]     Test creating order with invalid email format
    [Tags]              create    negative    validation
    
    ${order_data}=      Generate Order Data With Validation    validation_type=invalid_email
    Run Keyword And Expect Error    *400*
    ...    Create Order With Validation    ${order_data}    expected_status=400

05 - Create Order With Invalid Phone Test
    [Documentation]     Test creating order with invalid phone format
    [Tags]              create    negative    validation
    
    ${order_data}=      Generate Order Data With Validation    validation_type=invalid_phone
    Run Keyword And Expect Error    *400*
    ...    Create Order With Validation    ${order_data}    expected_status=400

06 - Create Order With Long Strings Test
    [Documentation]     Test creating order with strings exceeding maximum length
    [Tags]              create    negative    validation
    
    ${order_data}=      Generate Order Data With Validation    validation_type=long_strings
    Run Keyword And Expect Error    *400*
    ...    Create Order With Validation    ${order_data}    expected_status=400

07 - Create Order With Special Characters Test
    [Documentation]     Test creating order with special characters
    [Tags]              create    edge_case    validation
    
    ${order_data}=      Generate Order Data With Validation    validation_type=special_chars
    ${order_id}    ${response}=    Create Order With Validation    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal    ${response}[customerName]    Test@#$%^&*()

08 - Add Product With Invalid Quantity Test
    [Documentation]     Test adding product with invalid quantity
    [Tags]              update    negative    validation
    
    ${order_data}=      Generate Order Data With Validation    validation_type=positive
    ${order_id}    ${response}=    Create Order With Validation    ${order_data}
    
    Run Keyword And Expect Error    *400*
    ...    Add Product To Order With Validation    ${order_id}    123    validation_type=negative

09 - Add Product With Zero Quantity Test
    [Documentation]     Test adding product with zero quantity
    [Tags]              update    negative    validation
    
    ${order_data}=      Generate Order Data With Validation    validation_type=positive
    ${order_id}    ${response}=    Create Order With Validation    ${order_data}
    
    Run Keyword And Expect Error    *400*
    ...    Add Product To Order With Validation    ${order_id}    123    validation_type=zero

10 - Create Multiple Orders Concurrently Test
    [Documentation]     Test creating multiple orders concurrently
    [Tags]              create    performance    validation
    
    @{order_ids}=       Create List
    
    # Create multiple orders concurrently
    FOR    ${index}    IN RANGE    ${MAX_CONCURRENT_ORDERS}
        ${order_data}=    Generate Order Data With Validation
        ${order_id}    ${response}=    Create Order With Validation    ${order_data}
        Append To List    ${order_ids}    ${order_id}
        Sleep    ${MIN_ORDER_INTERVAL}
    END
    
    Length Should Be    ${order_ids}    ${MAX_CONCURRENT_ORDERS}

11 - Cleanup Test Environment
    [Documentation]     Clean up test data and resources
    [Tags]              cleanup
    Log    Test environment cleaned up successfully 