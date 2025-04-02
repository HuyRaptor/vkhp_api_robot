*** Settings ***
Documentation     Comprehensive Test Suite for Order Processing Operations
...               Includes order creation, status tracking, and updates
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_ID}         6
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_ORDER_ID}        ${EMPTY}
${TEST_ORDER_DATA}      ${EMPTY}
${TEST_PRODUCT_ORDER_ID} ${EMPTY}

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
    # Send login request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    # Save token for subsequent tests
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    # Create results directory if it doesn't exist
    Create Directory    ${RESULTS_DIR}

Generate Unique Order Data
    [Documentation]     Generate unique data for order tests
    [Arguments]         ${custom_name}=Test Order
    
    ${timestamp}=       Get Time    epoch
    ${order_code}=      Set Variable    ORD${timestamp}
    
    # Create order data
    ${order_data}=      Create Dictionary
    ...                 code=${order_code}
    ...                 customerName=Test Customer ${timestamp}
    ...                 customerPhone=800${timestamp}
    ...                 customerEmail=customer${timestamp}@example.com
    ...                 deliveryAddress=Test Address ${timestamp}
    ...                 deliveryTime=2024-04-02T10:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=DRAFT
    
    RETURN           ${order_data}

Create Order
    [Documentation]     Create a new order and return its ID
    [Arguments]         ${order_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${order_data}    customerName
    ...    msg=Missing required parameter: customerName
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create order request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Get Time    epoch
    Create File         ${RESULTS_DIR}${/}order_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}    msg=Create order response was empty
    Dictionary Should Contain Key    ${json}    id    msg=Create order response missing ID field
    
    # Return order ID and full response
    ${order_id}=        Convert To String    ${json}[id]
    RETURN           ${order_id}    ${json}

Add Product To Order
    [Documentation]     Add a product to an existing order
    [Arguments]         ${order_id}    ${product_id}    ${quantity}=1
    
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

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    
    Should Not Be Empty    ${order_id}    msg=Order ID cannot be empty
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}    msg=Get order response was empty
    
    RETURN           ${json}

Update Order Status
    [Documentation]     Update order status
    [Arguments]         ${order_id}    ${new_status}
    
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

Cancel Order
    [Documentation]     Cancel an order
    [Arguments]         ${order_id}
    
    ${cancel_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 status=CANCELLED
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${cancel_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN           ${json}

Reschedule Order
    [Documentation]     Reschedule order delivery time
    [Arguments]         ${order_id}    ${new_delivery_time}
    
    ${reschedule_data}=    Create Dictionary
    ...                    id=${order_id}
    ...                    deliveryTime=${new_delivery_time}
    ...                    warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${reschedule_data}
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

02 - Create Order Test
    [Documentation]     Test creating a new order
    [Tags]              create    positive
    
    ${order_data}=      Generate Unique Order Data
    ${order_id}    ${response}=    Create Order    ${order_data}
    
    Should Not Be Empty    ${order_id}    msg=Failed to create order: No ID returned
    Should Be Equal    ${response}[code]    ${order_data}[code]
    
    Set Suite Variable    ${TEST_ORDER_ID}     ${order_id}
    Set Suite Variable    ${TEST_ORDER_DATA}   ${order_data}

03 - Add Product To Order Test
    [Documentation]     Test adding a product to an order
    [Tags]              create    positive
    
    ${product_id}=      Set Variable    123    # Replace with actual product ID
    ${product_order_id}    ${response}=    Add Product To Order    ${TEST_ORDER_ID}    ${product_id}    2
    
    Should Not Be Empty    ${product_order_id}    msg=Failed to add product to order
    Set Suite Variable    ${TEST_PRODUCT_ORDER_ID}    ${product_order_id}

04 - Update Order Status Test
    [Documentation]     Test updating order status through workflow
    [Tags]              update    positive
    
    # Update to PICKING
    ${response}=        Update Order Status    ${TEST_ORDER_ID}    PICKING
    Should Be Equal    ${response}[status]    PICKING
    
    # Update to PACKAGED
    ${response}=        Update Order Status    ${TEST_ORDER_ID}    PACKAGED
    Should Be Equal    ${response}[status]    PACKAGED
    
    # Update to SHIPPED
    ${response}=        Update Order Status    ${TEST_ORDER_ID}    SHIPPED
    Should Be Equal    ${response}[status]    SHIPPED

05 - Reschedule Order Test
    [Documentation]     Test rescheduling order delivery time
    [Tags]              update    positive
    
    ${new_delivery_time}=    Set Variable    2024-04-03T15:00:00.000Z
    ${response}=            Reschedule Order    ${TEST_ORDER_ID}    ${new_delivery_time}
    
    Should Be Equal    ${response}[deliveryTime]    ${new_delivery_time}
    ...    msg=Order delivery time was not updated correctly

06 - Cancel Order Test
    [Documentation]     Test cancelling an order
    [Tags]              update    positive
    
    ${response}=        Cancel Order    ${TEST_ORDER_ID}
    Should Be Equal    ${response}[status]    CANCELLED
    ...    msg=Order was not cancelled successfully

07 - Get Order Details Test
    [Documentation]     Test retrieving order details
    [Tags]              retrieve    positive
    
    ${order}=          Get Order By ID    ${TEST_ORDER_ID}
    
    Should Be Equal    ${order}[id]    ${TEST_ORDER_ID}
    Should Be Equal    ${order}[code]    ${TEST_ORDER_DATA}[code]
    Should Be Equal    ${order}[customerName]    ${TEST_ORDER_DATA}[customerName]

08 - Create Order Missing Required Field Test
    [Documentation]     Test creating an order with missing required fields
    [Tags]              create    negative
    
    ${incomplete_data}=    Generate Unique Order Data
    Remove From Dictionary    ${incomplete_data}    customerName
    
    Run Keyword And Expect Error    *Missing required parameter: customerName*
    ...    Create Order    ${incomplete_data}

09 - Update Non-Existent Order Test
    [Documentation]     Test updating a non-existent order
    [Tags]              update    negative
    
    ${non_existent_id}=    Set Variable    99999999
    ${headers}=            Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...    Update Order Status    ${non_existent_id}    PICKING

10 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    Log                 Test environment cleaned up successfully 