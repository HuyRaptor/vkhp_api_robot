*** Settings ***
Documentation     Advanced E2E Test Suite for Order Management with Complex Validation
...               Includes business rules, data integrity, and system constraints
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Library           Process
Library           JSONLibrary
Library           DatabaseLibrary

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
${MAX_ITEMS_PER_ORDER}  100
${MAX_TOTAL_AMOUNT}     1000000
${MIN_DELIVERY_TIME}    1h
${MAX_DELIVERY_TIME}    7d

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

Generate Complex Order Data
    [Documentation]     Generate complex order data with business rules
    [Arguments]         ${custom_name}=Test Order    ${include_optional}=${TRUE}    ${business_rules}=${FALSE}
    
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
    
    IF    ${business_rules}
        Set To Dictionary    ${order_data}
        ...                 totalAmount=0
        ...                 itemCount=0
        ...                 deliveryZone=ZONE_A
        ...                 customerType=REGULAR
        ...                 discountCode=${EMPTY}
        ...                 taxRate=0.1
        ...                 shippingFee=0
    END
    
    RETURN           ${order_data}

Create Order With Business Rules
    [Documentation]     Create order with business rule validation
    [Arguments]         ${order_data}
    
    # Basic validation
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${order_data}    customerName
    ...    msg=Missing required parameter: customerName
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Business rule validations
    IF    'totalAmount' in ${order_data}
        Should Be True    ${order_data}[totalAmount] <= ${MAX_TOTAL_AMOUNT}
        ...    msg=Order total amount exceeds maximum allowed
    END
    
    IF    'itemCount' in ${order_data}
        Should Be True    ${order_data}[itemCount] <= ${MAX_ITEMS_PER_ORDER}
        ...    msg=Order item count exceeds maximum allowed
    END
    
    IF    'deliveryTime' in ${order_data}
        ${delivery_time}=    Convert To String    ${order_data}[deliveryTime]
        ${current_time}=    Get Time    epoch
        ${delivery_epoch}=    Convert To Integer    ${delivery_time}
        ${time_diff}=    Evaluate    ${delivery_epoch} - ${current_time}
        
        Should Be True    ${time_diff} >= ${MIN_DELIVERY_TIME}
        ...    msg=Delivery time is too soon
        Should Be True    ${time_diff} <= ${MAX_DELIVERY_TIME}
        ...    msg=Delivery time is too far in the future
    END
    
    # Customer type specific rules
    IF    'customerType' in ${order_data}
        ${valid_types}=    Create List    REGULAR    VIP    WHOLESALE
        Should Contain    ${valid_types}    ${order_data}[customerType]
        ...    msg=Invalid customer type: ${order_data}[customerType]
    END
    
    # Discount code validation
    IF    'discountCode' in ${order_data} and "${order_data}[discountCode]" != "${EMPTY}"
        ${valid_codes}=    Create List    VIP10    WHOLESALE20    SPECIAL30
        Should Contain    ${valid_codes}    ${order_data}[discountCode]
        ...    msg=Invalid discount code: ${order_data}[discountCode]
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

Add Product To Order With Business Rules
    [Documentation]     Add product to order with business rule validation
    [Arguments]         ${order_id}    ${product_id}    ${quantity}=1    ${price}=0    ${special_instructions}=${EMPTY}
    
    # Basic quantity validation
    Should Be True      ${quantity} >= ${MIN_QUANTITY}
    ...    msg=Quantity below minimum allowed
    Should Be True      ${quantity} <= ${MAX_QUANTITY}
    ...    msg=Quantity exceeds maximum allowed
    
    # Get current order status and details
    ${order}=          Get Order By ID    ${order_id}
    Should Be Equal    ${order}[status]    DRAFT
    ...    msg=Cannot add products to order in status: ${order}[status]
    
    # Check item count limit
    ${current_items}=    Set Variable    ${order}[itemCount]
    Should Be True    ${current_items} + ${quantity} <= ${MAX_ITEMS_PER_ORDER}
    ...    msg=Adding ${quantity} items would exceed maximum items per order
    
    # Check total amount limit
    ${current_total}=    Set Variable    ${order}[totalAmount]
    ${new_total}=       Evaluate    ${current_total} + (${quantity} * ${price})
    Should Be True    ${new_total} <= ${MAX_TOTAL_AMOUNT}
    ...    msg=Adding items would exceed maximum order amount
    
    ${product_order_data}=    Create Dictionary
    ...                      orderId=${order_id}
    ...                      productId=${product_id}
    ...                      quantity=${quantity}
    ...                      price=${price}
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

Update Order Status With Business Rules
    [Documentation]     Update order status with business rule validation
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
    
    # Business rule validations
    IF    "${new_status}" != "CANCELLED" and "${new_status}" != "DRAFT"
        # Check minimum order amount
        Should Be True    ${current_order}[totalAmount] > 0
        ...    msg=Cannot change status to ${new_status} with zero amount
        
        # Check item count
        Should Be True    ${current_order}[itemCount] > 0
        ...    msg=Cannot change status to ${new_status} without items
        
        # Check delivery time for shipping
        IF    "${new_status}" == "SHIPPED"
            ${delivery_time}=    Convert To String    ${current_order}[deliveryTime]
            ${current_time}=    Get Time    epoch
            ${delivery_epoch}=    Convert To Integer    ${delivery_time}
            Should Be True    ${delivery_epoch} > ${current_time}
            ...    msg=Cannot ship order with past delivery time
        END
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

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Order With Business Rules Test
    [Documentation]     Test creating order with business rules
    [Tags]              create    positive    business_rules
    
    ${order_data}=      Generate Complex Order Data    include_optional=${TRUE}    business_rules=${TRUE}
    ${order_id}    ${response}=    Create Order With Business Rules    ${order_data}
    
    Should Not Be Empty    ${order_id}    msg=Failed to create order: No ID returned
    Should Be Equal    ${response}[code]    ${order_data}[code]
    Should Be Equal    ${response}[customerType]    ${order_data}[customerType]
    
    Set Suite Variable    ${TEST_ORDER_ID}     ${order_id}
    Set Suite Variable    ${TEST_ORDER_DATA}   ${order_data}

03 - Create Order With Invalid Delivery Time Test
    [Documentation]     Test creating order with invalid delivery time
    [Tags]              create    negative    validation
    
    ${past_time}=       Get Time    epoch    NOW - 1 day
    ${order_data}=      Generate Complex Order Data
    Set To Dictionary    ${order_data}    deliveryTime=${past_time}
    
    Run Keyword And Expect Error    *Delivery time is too soon*
    ...    Create Order With Business Rules    ${order_data}

04 - Add Product With Amount Limit Test
    [Documentation]     Test adding product that exceeds amount limit
    [Tags]              create    negative    business_rules
    
    ${product_id}=      Set Variable    123    # Replace with actual product ID
    ${high_price}=      Set Variable    1000001    # Price that would exceed MAX_TOTAL_AMOUNT
    
    Run Keyword And Expect Error    *Adding items would exceed maximum order amount*
    ...    Add Product To Order With Business Rules    ${TEST_ORDER_ID}    ${product_id}    1    ${high_price}

05 - Add Product With Item Limit Test
    [Documentation]     Test adding product that exceeds item limit
    [Tags]              create    negative    business_rules
    
    ${product_id}=      Set Variable    123    # Replace with actual product ID
    ${high_quantity}=   Set Variable    101    # Quantity that would exceed MAX_ITEMS_PER_ORDER
    
    Run Keyword And Expect Error    *Adding ${high_quantity} items would exceed maximum items per order*
    ...    Add Product To Order With Business Rules    ${TEST_ORDER_ID}    ${product_id}    ${high_quantity}

06 - Order Status Transition With Business Rules Test
    [Documentation]     Test order status transition with business rules
    [Tags]              update    positive    workflow
    
    # First ensure order is in DRAFT status
    ${response}=        Update Order Status With Business Rules    ${TEST_ORDER_ID}    DRAFT
    
    # Try to transition to PICKING without items
    Run Keyword And Expect Error    *Cannot change status to PICKING without items*
    ...    Update Order Status With Business Rules    ${TEST_ORDER_ID}    PICKING
    
    # Add product and try again
    ${product_id}=      Set Variable    123    # Replace with actual product ID
    ${product_order_id}    ${response}=    Add Product To Order With Business Rules
    ...    ${TEST_ORDER_ID}    ${product_id}    1    100
    
    ${response}=        Update Order Status With Business Rules    ${TEST_ORDER_ID}    PICKING
    Should Be Equal    ${response}[status]    PICKING

07 - Order Shipping With Past Delivery Time Test
    [Documentation]     Test shipping order with past delivery time
    [Tags]              update    negative    business_rules
    
    ${past_time}=       Get Time    epoch    NOW - 1 day
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 deliveryTime=${past_time}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    
    Run Keyword And Expect Error    *Cannot ship order with past delivery time*
    ...    Update Order Status With Business Rules    ${TEST_ORDER_ID}    SHIPPED

08 - Customer Type Specific Rules Test
    [Documentation]     Test customer type specific business rules
    [Tags]              create    positive    business_rules
    
    ${order_data}=      Generate Complex Order Data
    Set To Dictionary    ${order_data}    customerType=VIP
    
    ${order_id}    ${response}=    Create Order With Business Rules    ${order_data}
    Should Not Be Empty    ${order_id}
    
    # Test VIP discount code
    Set To Dictionary    ${order_data}    discountCode=VIP10
    ${order_id}    ${response}=    Create Order With Business Rules    ${order_data}
    Should Not Be Empty    ${order_id}
    
    # Test invalid customer type
    Set To Dictionary    ${order_data}    customerType=INVALID_TYPE
    Run Keyword And Expect Error    *Invalid customer type*
    ...    Create Order With Business Rules    ${order_data}

09 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    Log                 Test environment cleaned up successfully 