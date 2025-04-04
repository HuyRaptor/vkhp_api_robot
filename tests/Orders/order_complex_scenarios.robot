*** Settings ***
Documentation     End-to-End Test Suite for Order Management in vKho API
...               Covers order creation, picking, confirmation, and cancellation workflows
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

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
    
    # Save token
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    # Create results directory
    Create Directory    ${RESULTS_DIR}

Generate Unique Order Data
    [Documentation]     Generate unique data for order creation
    [Arguments]         ${custom_code}=TestOrder
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     ORD${custom_code}${timestamp}
    ${customer_name}=   Set Variable     Customer ${timestamp}
    
    # Sample product item for the order
    ${item}=            Create Dictionary
    ...                 productId=${PRODUCT_ID}
    ...                 quantity=5
    ...                 price=75.00
    
    ${items}=           Create List    ${item}
    
    ${order_data}=      Create Dictionary
    ...                 orderCode=${order_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 customerName=${customer_name}
    ...                 customerPhone=1234567890
    ...                 customerAddress=123 Test St, Warehouse City
    ...                 items=${items}
    ...                 totalAmount=375.00  # 5 * 75.00
    ...                 status=NEW
    ...                 note=Test order note
    
    RETURN            ${order_data}

Create Test Product
    [Documentation]     Create a test product for order tests
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Order Test Product ${timestamp}
    ...                 totalQuantity=100
    ...                 expectedQuantity=100
    ...                 importDate=2025-03-31T00:00:00.000Z
    ...                 cost=50.00
    ...                 salePrice=75.00
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-03-31T00:00:00.000Z
    ...                 productCode=PRD${timestamp}
    ...                 supplierId=56
    ...                 productCategoryId=37
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${product_id}=      Convert To String    ${json}[id]
    Set Global Variable  ${PRODUCT_ID}    ${product_id}

Create Order
    [Documentation]     Create a new order
    [Arguments]         ${order_data}
    
    # Validate required fields
    FOR    ${key}    IN    orderCode    warehouseId    items
        Should Not Be Empty    ${order_data}[${key}]
        ...    msg=Missing or empty required parameter: ${key}
    END
    
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
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}order_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create order response missing ID field
    
    ${order_id}=        Convert To String    ${json}[id]
    RETURN            ${order_id}    ${json}

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get order response was empty
    
    RETURN            ${json}

Update Order Status
    [Documentation]     Update the status of an order
    [Arguments]         ${order_id}    ${new_status}
    
    ${update_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 status=${new_status}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update-status
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal     ${json}[status]    ${new_status}
    ...    msg=Order status update failed
    
    RETURN            ${json}

Pick Order
    [Documentation]     Simulate picking an order
    [Arguments]         ${order_id}
    
    ${pick_data}=       Create Dictionary
    ...                 orderId=${order_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 pickerId=1  # Assuming a valid picker ID
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/pick
    ...                 json=${pick_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Contain Any    ${json}[status]    PICKING    PICKED
    ...    msg=Order picking failed
    
    RETURN            ${json}

Cancel Order
    [Documentation]     Cancel an existing order
    [Arguments]         ${order_id}
    
    ${cancel_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 reason=Test cancellation
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 /orders/cancel
    ...                 json=${cancel_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal     ${json}[status]    CANCELLED
    ...    msg=Order cancellation failed
    
    RETURN            ${json}

Assert Order Details
    [Documentation]     Verify order details match expected values
    [Arguments]         ${order}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${order}    Should Be Equal    ${order}[${key}]    ${expected_data}[${key}]
        ...    msg=Order ${key} value '${order}[${key}]' does not match expected '${expected_data}[${key}]'
    END

*** Test Cases ***
01 - Setup Order Test Environment
    [Documentation]     Setup API session and create a test product for order tests
    [Tags]              setup
    Setup API Session
    Create Test Product
    Log                 Successfully set up environment with product ID: ${PRODUCT_ID}

02 - Create Order Flow
    [Documentation]     Test creating a new order
    [Tags]              create    positive
    
    ${order_data}=      Generate Unique Order Data
    ${order_id}    ${response}=    Create Order    ${order_data}
    
    Should Not Be Empty    ${order_id}
    ...    msg=Failed to create order: No ID returned
    Assert Order Details    ${response}    ${order_data}
    
    Set Global Variable  ${ORDER_ID}    ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[orderCode]
    Log                 Successfully created order: ${TEST_ORDER_CODE} with ID: ${ORDER_ID}

03 - Order Picking Flow
    [Documentation]     Test picking an order from NEW to PICKED status
    [Tags]              picking    positive
    
    Run Keyword If      "${ORDER_ID}" == "${EMPTY}"    Create Order Flow
    ${initial_order}=   Get Order By ID    ${ORDER_ID}
    Should Be Equal     ${initial_order}[status]    NEW
    ...    msg=Order should start with NEW status
    
    ${picked_order}=    Pick Order    ${ORDER_ID}
    Should Contain Any    ${picked_order}[status]    PICKING    PICKED
    ...    msg=Order status did not update to PICKING or PICKED
    
    Log                 Successfully picked order: ${TEST_ORDER_CODE}

04 - Order Confirmation Flow
    [Documentation]     Test confirming an order after picking
    [Tags]              confirmation    positive
    
    Run Keyword If      "${ORDER_ID}" == "${EMPTY}"    Create Order Flow
    Pick Order          ${ORDER_ID}  # Ensure order is picked first
    
    ${confirmed_order}=    Update Order Status    ${ORDER_ID}    CONFIRMED
    Should Be Equal     ${confirmed_order}[status]    CONFIRMED
    ...    msg=Order status did not update to CONFIRMED
    
    Log                 Successfully confirmed order: ${TEST_ORDER_CODE}

05 - Order Cancellation Flow
    [Documentation]     Test cancelling an order before fulfillment
    [Tags]              cancellation    positive
    
    Run Keyword If      "${ORDER_ID}" == "${EMPTY}"    Create Order Flow
    
    ${cancelled_order}=    Cancel Order    ${ORDER_ID}
    Should Be Equal     ${cancelled_order}[status]    CANCELLED
    ...    msg=Order status did not update to CANCELLED
    
    Log                 Successfully cancelled order: ${TEST_ORDER_CODE}

06 - Create Order With Missing Items Test
    [Documentation]     Test creating an order without items
    [Tags]              create    negative
    
    ${invalid_data}=    Generate Unique Order Data
    Set To Dictionary   ${invalid_data}    items=${EMPTY}
    
    Run Keyword And Expect Error    *Missing or empty required parameter: items*
    ...                 Create Order    ${invalid_data}
    
    Log                 Successfully verified that orders without items are rejected

07 - Pick Non-Existent Order Test
    [Documentation]     Test picking an order that doesn’t exist
    [Tags]              picking    negative
    
    ${non_existent_id}=    Set Variable    99999999
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${pick_data}=       Create Dictionary    orderId=${non_existent_id}    warehouseId=${WAREHOUSE_ID}    pickerId=1
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /orders/pick
    ...                 json=${pick_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that picking a non-existent order fails

08 - Cancel Confirmed Order Test
    [Documentation]     Test attempting to cancel an already confirmed order
    [Tags]              cancellation    negative
    
    Run Keyword If      "${ORDER_ID}" == "${EMPTY}"    Create Order Flow
    Update Order Status    ${ORDER_ID}    CONFIRMED
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${cancel_data}=     Create Dictionary    id=${ORDER_ID}    reason=Invalid cancellation
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /orders/cancel
    ...                 json=${cancel_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that cancelling a confirmed order fails