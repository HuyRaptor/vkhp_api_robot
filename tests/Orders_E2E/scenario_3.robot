*** Settings ***
Documentation     Advanced E2E Test Suite for Order Management
...               Includes complex business rules, concurrent operations, and stress testing
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Library           Process
Library           JSONLibrary

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_ID}         6
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_ORDER_ID}        ${EMPTY}
${TEST_ORDER_DATA}      ${EMPTY}
${TEST_PRODUCT_ORDER_ID} ${EMPTY}
${TEST_CUSTOMER_ID}     ${EMPTY}
${MAX_QUANTITY}         9999
${MIN_QUANTITY}         1
${MAX_STRING_LENGTH}    255
${MIN_STRING_LENGTH}    1
${MAX_ORDERS}           10
${CONCURRENT_REQUESTS}  5
${TIMEOUT}              30s

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

Generate Advanced Order Data
    [Documentation]     Generate advanced order data with complex scenarios
    [Arguments]         ${custom_name}=Test Order    ${include_optional}=${TRUE}    ${special_cases}=${FALSE}
    
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
        ...                 specialInstructions=Handle with care
        ...                 isUrgent=${TRUE}
        ...                 requiresSignature=${TRUE}
    END
    
    IF    ${special_cases}
        Set To Dictionary    ${order_data}
        ...                 customFields=${EMPTY}
        ...                 metadata=${EMPTY}
        ...                 tags=${EMPTY}
    END
    
    RETURN           ${order_data}

Create Order With Advanced Validation
    [Documentation]     Create order with advanced validation rules
    [Arguments]         ${order_data}
    
    # Basic validation
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${order_data}    customerName
    ...    msg=Missing required parameter: customerName
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Advanced string validation
    ${name_length}=     Get Length    ${order_data}[customerName]
    Should Be True      ${name_length} <= ${MAX_STRING_LENGTH}
    ...    msg=Customer name exceeds maximum length
    Should Be True      ${name_length} >= ${MIN_STRING_LENGTH}
    ...    msg=Customer name is too short
    
    # Email validation with regex
    IF    'email' in ${order_data}
        Should Match Regexp    ${order_data}[email]    ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$
        ...    msg=Invalid email format
    END
    
    # Phone validation with regex
    IF    'customerPhone' in ${order_data}
        Should Match Regexp    ${order_data}[customerPhone]    ^\\d{10,}$
        ...    msg=Invalid phone number format
    END
    
    # Date validation
    IF    'deliveryTime' in ${order_data}
        ${delivery_time}=    Convert To String    ${order_data}[deliveryTime]
        Should Match Regexp    ${delivery_time}    ^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})$
        ...    msg=Invalid delivery time format
        
        # Validate delivery time is in the future
        ${current_time}=    Get Time    epoch
        ${delivery_epoch}=    Convert To Integer    ${delivery_time}
        Should Be True    ${delivery_epoch} > ${current_time}
        ...    msg=Delivery time must be in the future
    END
    
    # Priority validation
    IF    'priority' in ${order_data}
        ${valid_priorities}=    Create List    LOW    MEDIUM    HIGH    URGENT
        Should Contain    ${valid_priorities}    ${order_data}[priority]
        ...    msg=Invalid priority value: ${order_data}[priority]
    END
    
    # Payment method validation
    IF    'paymentMethod' in ${order_data}
        ${valid_methods}=    Create List    COD    CREDIT_CARD    BANK_TRANSFER
        Should Contain    ${valid_methods}    ${order_data}[paymentMethod]
        ...    msg=Invalid payment method: ${order_data}[paymentMethod]
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

Add Product To Order With Advanced Validation
    [Documentation]     Add product to order with advanced validation rules
    [Arguments]         ${order_id}    ${product_id}    ${quantity}=1    ${special_instructions}=${EMPTY}
    
    # Basic quantity validation
    Should Be True      ${quantity} >= ${MIN_QUANTITY}
    ...    msg=Quantity below minimum allowed
    Should Be True      ${quantity} <= ${MAX_QUANTITY}
    ...    msg=Quantity exceeds maximum allowed
    
    # Check order status before adding product
    ${order}=          Get Order By ID    ${order_id}
    Should Be Equal    ${order}[status]    DRAFT
    ...    msg=Cannot add products to order in status: ${order}[status]
    
    ${product_order_data}=    Create Dictionary
    ...                      orderId=${order_id}
    ...                      productId=${product_id}
    ...                      quantity=${quantity}
    ...                      warehouseId=${WAREHOUSE_ID}
    
    IF    "${special_instructions}" != "${EMPTY}"
        Set To Dictionary    ${product_order_data}    specialInstructions=${special_instructions}
    END
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${product_order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN           ${json}[id]    ${json}

Update Order Status With Advanced Validation
    [Documentation]     Update order status with advanced validation rules
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
    
    # Validate order has products before status change
    IF    "${new_status}" != "CANCELLED" and "${new_status}" != "DRAFT"
        ${has_products}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key    ${current_order}    productOrders
        Should Be True    ${has_products}
        ...    msg=Cannot change status to ${new_status} without products
    END
    
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

Create Concurrent Orders
    [Documentation]     Create multiple orders concurrently
    [Arguments]         ${count}=${CONCURRENT_REQUESTS}
    
    ${order_ids}=       Create List
    ${processes}=       Create List
    
    FOR    ${i}    IN RANGE    ${count}
        ${order_data}=    Generate Advanced Order Data    custom_name=Concurrent Order ${i}
        ${process}=    Start Process    python    -c    "import requests; response = requests.post('${BASE_URL}/orders/create', json=${order_data}, headers={'Authorization': '${AUTH_TOKEN}'}); print(response.text)"
        Append To List    ${processes}    ${process}
    END
    
    FOR    ${process}    IN    @{processes}
        ${output}=    Wait For Process    ${process}    timeout=${TIMEOUT}
        ${json}=    Evaluate    json.loads('''${output.stdout}''')    json
        Append To List    ${order_ids}    ${json}[id]
    END
    
    RETURN           ${order_ids}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Order With Complex Data Test
    [Documentation]     Test creating order with complex data structure
    [Tags]              create    positive    complex
    
    ${order_data}=      Generate Advanced Order Data    include_optional=${TRUE}    special_cases=${TRUE}
    ${order_id}    ${response}=    Create Order With Advanced Validation    ${order_data}
    
    Should Not Be Empty    ${order_id}    msg=Failed to create order: No ID returned
    Should Be Equal    ${response}[code]    ${order_data}[code]
    Should Be Equal    ${response}[priority]    ${order_data}[priority]
    Should Be Equal    ${response}[isUrgent]    ${order_data}[isUrgent]
    
    Set Suite Variable    ${TEST_ORDER_ID}     ${order_id}
    Set Suite Variable    ${TEST_ORDER_DATA}   ${order_data}

03 - Create Order With Future Delivery Time Test
    [Documentation]     Test creating order with future delivery time
    [Tags]              create    positive    validation
    
    ${future_time}=     Get Time    epoch    NOW + 1 day
    ${order_data}=      Generate Advanced Order Data
    Set To Dictionary    ${order_data}    deliveryTime=${future_time}
    
    ${order_id}    ${response}=    Create Order With Advanced Validation    ${order_data}
    Should Not Be Empty    ${order_id}
    Should Be Equal    ${response}[deliveryTime]    ${future_time}

04 - Create Order With Invalid Priority Test
    [Documentation]     Test creating order with invalid priority
    [Tags]              create    negative    validation
    
    ${order_data}=      Generate Advanced Order Data
    Set To Dictionary    ${order_data}    priority=INVALID_PRIORITY
    
    Run Keyword And Expect Error    *Invalid priority value*
    ...    Create Order With Advanced Validation    ${order_data}

05 - Add Product To Order With Special Instructions Test
    [Documentation]     Test adding product with special instructions
    [Tags]              create    positive    complex
    
    ${product_id}=      Set Variable    123    # Replace with actual product ID
    ${special_instructions}=    Set Variable    Handle with extreme care
    
    ${product_order_id}    ${response}=    Add Product To Order With Advanced Validation
    ...    ${TEST_ORDER_ID}    ${product_id}    2    ${special_instructions}
    
    Should Not Be Empty    ${product_order_id}
    Should Be Equal    ${response}[specialInstructions]    ${special_instructions}

06 - Add Product To Non-Draft Order Test
    [Documentation]     Test adding product to order in non-draft status
    [Tags]              create    negative    workflow
    
    ${response}=        Update Order Status With Advanced Validation    ${TEST_ORDER_ID}    PICKING
    ${product_id}=      Set Variable    123    # Replace with actual product ID
    
    Run Keyword And Expect Error    *Cannot add products to order in status*
    ...    Add Product To Order With Advanced Validation    ${TEST_ORDER_ID}    ${product_id}

07 - Concurrent Order Creation Test
    [Documentation]     Test creating multiple orders concurrently
    [Tags]              create    positive    performance
    
    ${order_ids}=       Create Concurrent Orders    ${CONCURRENT_REQUESTS}
    Should Be True    len(${order_ids}) == ${CONCURRENT_REQUESTS}
    ...    msg=Not all concurrent orders were created successfully

08 - Order Status Transition With Products Test
    [Documentation]     Test order status transition with product validation
    [Tags]              update    positive    workflow
    
    # First ensure order is in DRAFT status
    ${response}=        Update Order Status With Advanced Validation    ${TEST_ORDER_ID}    DRAFT
    
    # Try to transition to PICKING without products
    Run Keyword And Expect Error    *Cannot change status to PICKING without products*
    ...    Update Order Status With Advanced Validation    ${TEST_ORDER_ID}    PICKING
    
    # Add product and try again
    ${product_id}=      Set Variable    123    # Replace with actual product ID
    ${product_order_id}    ${response}=    Add Product To Order With Advanced Validation
    ...    ${TEST_ORDER_ID}    ${product_id}
    
    ${response}=        Update Order Status With Advanced Validation    ${TEST_ORDER_ID}    PICKING
    Should Be Equal    ${response}[status]    PICKING

09 - Order Cancellation With Products Test
    [Documentation]     Test order cancellation with product validation
    [Tags]              update    positive    workflow
    
    ${response}=        Update Order Status With Advanced Validation    ${TEST_ORDER_ID}    CANCELLED
    Should Be Equal    ${response}[status]    CANCELLED
    
    # Verify products are still associated with cancelled order
    ${order}=          Get Order By ID    ${TEST_ORDER_ID}
    Dictionary Should Contain Key    ${order}    productOrders
    ...    msg=Products were removed from cancelled order

10 - Edge Cases With Special Characters Test
    [Documentation]     Test order creation with special characters
    [Tags]              edge    validation
    
    ${special_chars}=    Set Variable    !@#$%^&*()_+{}[]|\\:;"'<>,.?/~`
    ${order_data}=      Generate Advanced Order Data
    Set To Dictionary    ${order_data}
    ...    customerName=Special ${special_chars} Customer
    ...    deliveryAddress=Address with ${special_chars}
    
    ${order_id}    ${response}=    Create Order With Advanced Validation    ${order_data}
    Should Not Be Empty    ${order_id}
    Should Be Equal    ${response}[customerName]    ${order_data}[customerName]
    Should Be Equal    ${response}[deliveryAddress]    ${order_data}[deliveryAddress]

11 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    Log                 Test environment cleaned up successfully 