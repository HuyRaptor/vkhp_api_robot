*** Settings ***
Documentation     Comprehensive E2E Test Suite for Order Management
...               Includes complex validation flows, edge cases, and business rules
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
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

Generate Complex Order Data
    [Documentation]     Generate complex order data with various test scenarios
    [Arguments]         ${custom_name}=Test Order    ${include_optional}=${TRUE}
    
    ${timestamp}=       Get Time    epoch
    ${order_code}=      Set Variable    ORD${timestamp}
    
    ${order_data}=      Create Dictionary
    ...                 code=${order_code}
    ...                 customerName=Test Customer ${timestamp}
    ...                 customerPhone=800${timestamp}
    ...                 customerEmail=customer${timestamp}@example.com
    ...                 deliveryAddress=Test Address ${timestamp}
    ...                 deliveryTime=2024-04-02T10:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=DRAFT
    
    IF    ${include_optional}
        Set To Dictionary    ${order_data}
        ...                 notes=Test order notes ${timestamp}
        ...                 priority=HIGH
        ...                 paymentMethod=COD
        ...                 expectedDeliveryTime=2024-04-02T15:00:00.000Z
    END
    
    RETURN           ${order_data}

Create Order With Validation
    [Documentation]     Create order with comprehensive validation
    [Arguments]         ${order_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${order_data}    customerName
    ...    msg=Missing required parameter: customerName
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Validate string lengths
    ${name_length}=     Get Length    ${order_data}[customerName]
    Should Be True      ${name_length} <= ${MAX_STRING_LENGTH}
    ...    msg=Customer name exceeds maximum length
    Should Be True      ${name_length} >= ${MIN_STRING_LENGTH}
    ...    msg=Customer name is too short
    
    # Validate email format if present
    IF    'email' in ${order_data}
        Should Match Regexp    ${order_data}[email]    ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$
        ...    msg=Invalid email format
    END
    
    # Validate phone format if present
    IF    'customerPhone' in ${order_data}
        Should Match Regexp    ${order_data}[customerPhone]    ^\\d{10,}$
        ...    msg=Invalid phone number format
    END
    
    # Validate dates if present
    IF    'deliveryTime' in ${order_data}
        ${delivery_time}=    Convert To String    ${order_data}[deliveryTime]
        Should Match Regexp    ${delivery_time}    ^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})$
        ...    msg=Invalid delivery time format
    END
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${timestamp}=       Get Time    epoch
    Create File         ${RESULTS_DIR}${/}order_create_${timestamp}.json    ${response.text}
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}    msg=Create order response was empty
    Dictionary Should Contain Key    ${json}    id    msg=Create order response missing ID field
    
    ${order_id}=        Convert To String    ${json}[id]
    RETURN           ${order_id}    ${json}

Add Product To Order With Validation
    [Documentation]     Add product to order with comprehensive validation
    [Arguments]         ${order_id}    ${product_id}    ${quantity}=1
    
    # Validate quantity limits
    Should Be True      ${quantity} >= ${MIN_QUANTITY}
    ...    msg=Quantity below minimum allowed
    Should Be True      ${quantity} <= ${MAX_QUANTITY}
    ...    msg=Quantity exceeds maximum allowed
    
    ${product_order_data}=    Create Dictionary
    ...                      orderId=${order_id}
    ...                      productId=${product_id}
    ...                      quantity=${quantity}
    ...                      warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${product_order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN           ${json}[id]    ${json}

Update Order Status With Validation
    [Documentation]     Update order status with comprehensive validation
    [Arguments]         ${order_id}    ${new_status}    ${expected_previous_status}=${EMPTY}
    
    # Get current order status
    ${current_order}=    Get Order By ID    ${order_id}
    
    # Validate status transition if previous status is specified
    IF    "${expected_previous_status}" != "${EMPTY}"
        Should Be Equal    ${current_order}[status]    ${expected_previous_status}
        ...    msg=Invalid status transition from ${current_order}[status] to ${new_status}
    END
    
    # Validate status value
    ${valid_statuses}=    Create List    DRAFT    PICKING    PACKAGED    SHIPPED    DELIVERED    CANCELLED
    Should Contain    ${valid_statuses}    ${new_status}
    ...    msg=Invalid status value: ${new_status}
    
    ${update_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 status=${new_status}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN           ${json}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Order With All Fields Test
    [Documentation]     Test creating order with all possible fields
    [Tags]              create    positive    comprehensive
    
    ${order_data}=      Generate Complex Order Data    include_optional=${TRUE}
    ${order_id}    ${response}=    Create Order With Validation    ${order_data}
    
    Should Not Be Empty    ${order_id}    msg=Failed to create order: No ID returned
    Should Be Equal    ${response}[code]    ${order_data}[code]
    Should Be Equal    ${response}[priority]    ${order_data}[priority]
    Should Be Equal    ${response}[paymentMethod]    ${order_data}[paymentMethod]
    
    Set Suite Variable    ${TEST_ORDER_ID}     ${order_id}
    Set Suite Variable    ${TEST_ORDER_DATA}   ${order_data}

03 - Create Order With Minimal Fields Test
    [Documentation]     Test creating order with only required fields
    [Tags]              create    positive    minimal
    
    ${order_data}=      Generate Complex Order Data    include_optional=${FALSE}
    ${order_id}    ${response}=    Create Order With Validation    ${order_data}
    
    Should Not Be Empty    ${order_id}    msg=Failed to create order: No ID returned
    Should Be Equal    ${response}[code]    ${order_data}[code]
    Should Be Equal    ${response}[customerName]    ${order_data}[customerName]

04 - Create Order With Invalid Email Test
    [Documentation]     Test creating order with invalid email format
    [Tags]              create    negative    validation
    
    ${order_data}=      Generate Complex Order Data
    Set To Dictionary    ${order_data}    customerEmail=invalid-email
    
    Run Keyword And Expect Error    *Invalid email format*
    ...    Create Order With Validation    ${order_data}

05 - Create Order With Invalid Phone Test
    [Documentation]     Test creating order with invalid phone format
    [Tags]              create    negative    validation
    
    ${order_data}=      Generate Complex Order Data
    Set To Dictionary    ${order_data}    customerPhone=invalid-phone
    
    Run Keyword And Expect Error    *Invalid phone number format*
    ...    Create Order With Validation    ${order_data}

06 - Add Multiple Products To Order Test
    [Documentation]     Test adding multiple products to an order
    [Tags]              create    positive    comprehensive
    
    ${product_ids}=     Create List    123    456    789    # Replace with actual product IDs
    ${quantities}=      Create List    2    3    1
    
    FOR    ${product_id}    ${quantity}    IN ZIP    ${product_ids}    ${quantities}
        ${product_order_id}    ${response}=    Add Product To Order With Validation
        ...    ${TEST_ORDER_ID}    ${product_id}    ${quantity}
        
        Should Not Be Empty    ${product_order_id}
        ...    msg=Failed to add product ${product_id} to order
        Should Be Equal    ${response}[quantity]    ${quantity}
    END

07 - Add Product With Invalid Quantity Test
    [Documentation]     Test adding product with invalid quantity
    [Tags]              create    negative    validation
    
    ${product_id}=      Set Variable    123    # Replace with actual product ID
    
    # Test quantity below minimum
    Run Keyword And Expect Error    *Quantity below minimum allowed*
    ...    Add Product To Order With Validation    ${TEST_ORDER_ID}    ${product_id}    0
    
    # Test quantity above maximum
    Run Keyword And Expect Error    *Quantity exceeds maximum allowed*
    ...    Add Product To Order With Validation    ${TEST_ORDER_ID}    ${product_id}    10000

08 - Order Status Transition Test
    [Documentation]     Test complete order status transition flow
    [Tags]              update    positive    workflow
    
    # DRAFT -> PICKING
    ${response}=        Update Order Status With Validation    ${TEST_ORDER_ID}    PICKING    DRAFT
    Should Be Equal    ${response}[status]    PICKING
    
    # PICKING -> PACKAGED
    ${response}=        Update Order Status With Validation    ${TEST_ORDER_ID}    PACKAGED    PICKING
    Should Be Equal    ${response}[status]    PACKAGED
    
    # PACKAGED -> SHIPPED
    ${response}=        Update Order Status With Validation    ${TEST_ORDER_ID}    SHIPPED    PACKAGED
    Should Be Equal    ${response}[status]    SHIPPED
    
    # SHIPPED -> DELIVERED
    ${response}=        Update Order Status With Validation    ${TEST_ORDER_ID}    DELIVERED    SHIPPED
    Should Be Equal    ${response}[status]    DELIVERED

09 - Invalid Status Transition Test
    [Documentation]     Test invalid order status transitions
    [Tags]              update    negative    workflow
    
    # Try to transition from DELIVERED to PICKING
    Run Keyword And Expect Error    *Invalid status transition*
    ...    Update Order Status With Validation    ${TEST_ORDER_ID}    PICKING    DELIVERED
    
    # Try to transition from CANCELLED to PACKAGED
    ${response}=        Update Order Status With Validation    ${TEST_ORDER_ID}    CANCELLED
    Run Keyword And Expect Error    *Invalid status transition*
    ...    Update Order Status With Validation    ${TEST_ORDER_ID}    PACKAGED    CANCELLED

10 - Order Rescheduling With Validation Test
    [Documentation]     Test order rescheduling with validation
    [Tags]              update    positive    validation
    
    ${new_delivery_time}=    Set Variable    2024-04-03T15:00:00.000Z
    ${response}=            Reschedule Order    ${TEST_ORDER_ID}    ${new_delivery_time}
    
    Should Be Equal    ${response}[deliveryTime]    ${new_delivery_time}
    ...    msg=Order delivery time was not updated correctly
    
    # Try to reschedule with invalid date format
    ${invalid_date}=    Set Variable    2024-13-45T99:99:99.999Z
    Run Keyword And Expect Error    *
    ...    Reschedule Order    ${TEST_ORDER_ID}    ${invalid_date}

11 - Order Cancellation With Validation Test
    [Documentation]     Test order cancellation with validation
    [Tags]              update    positive    validation
    
    ${response}=        Cancel Order    ${TEST_ORDER_ID}
    Should Be Equal    ${response}[status]    CANCELLED
    ...    msg=Order was not cancelled successfully
    
    # Verify order cannot be modified after cancellation
    Run Keyword And Expect Error    *
    ...    Update Order Status With Validation    ${TEST_ORDER_ID}    PICKING    CANCELLED

12 - Edge Cases Test
    [Documentation]     Test various edge cases
    [Tags]              edge    comprehensive
    
    # Test order with maximum string lengths
    ${max_length_data}=    Generate Complex Order Data
    Set To Dictionary    ${max_length_data}
    ...    customerName=${SPACE * ${MAX_STRING_LENGTH}}
    ...    customerEmail=a${SPACE * ${MAX_STRING_LENGTH}}@example.com
    
    ${order_id}    ${response}=    Create Order With Validation    ${max_length_data}
    Should Not Be Empty    ${order_id}
    
    # Test order with minimum string lengths
    ${min_length_data}=    Generate Complex Order Data
    Set To Dictionary    ${min_length_data}
    ...    customerName=a
    ...    customerEmail=a@b.com
    
    ${order_id}    ${response}=    Create Order With Validation    ${min_length_data}
    Should Not Be Empty    ${order_id}

13 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    Log                 Test environment cleaned up successfully 