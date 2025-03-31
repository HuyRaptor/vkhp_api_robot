*** Settings ***
Documentation     End-to-End Test Suite for Bulk Order Management in vKho API
...               Covers bulk order creation, updates, confirmation, and cleanup
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
@{TEST_ORDER_IDS}       ${EMPTY}
${CONFIRMED_ORDER_ID}   ${EMPTY}

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
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Generate Unique Order Data
    [Documentation]     Generate unique data for order tests
    [Arguments]         ${custom_name}=Bulk Order
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     BULK${timestamp}
    
    ${product_order}=   Create Dictionary
    ...                 total=8
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=SKU${timestamp}
    ${product_orders}=  Create List      ${product_order}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=${custom_name} Customer
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}
    ...                 deliveryAdress=789 Bulk Ave
    ...                 deliveryTime=2025-04-03T10:00:00.000Z
    ...                 driverName=Sam Smith
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${product_orders}
    RETURN            ${order_data}

Create Order
    [Documentation]     Create a new order and return its ID
    [Arguments]         ${order_data}
    
    Dictionary Should Contain Key    ${order_data}    code
    Dictionary Should Contain Key    ${order_data}    warehouseId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}order_create_${timestamp}.json    ${response.text}
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    Dictionary Should Contain Key        ${json}    id
    
    ${order_id}=        Convert To String    ${json}[id]
    RETURN            ${order_id}    ${json}

Get All Orders
    [Documentation]     Retrieve all orders with optional filters
    [Arguments]         ${warehouse_id}=${WAREHOUSE_ID}    ${status}=${NONE}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${params}=          Create Dictionary    warehouseId=${warehouse_id}
    Run Keyword If      "${status}" != "${NONE}"    Set To Dictionary    ${params}    status=${status}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-all
    ...                 headers=${headers}
    ...                 params=${params}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    
    RETURN            ${json}

Bulk Update Orders
    [Documentation]     Update multiple orders' status in bulk
    [Arguments]         ${order_ids}    ${status}
    
    Should Not Be Empty    ${order_ids}
    
    ${update_data}=     Create Dictionary    ids=${order_ids}    status=${status}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/updates
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    
    RETURN            ${json}

Check Picking Orders
    [Documentation]     Check picking availability for multiple orders
    [Arguments]         ${order_ids}    ${user_id}=bulk-user
    
    Should Not Be Empty    ${order_ids}
    
    ${check_data}=      Create Dictionary    ids=${order_ids}    userId=${user_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/check/picking
    ...                 json=${check_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    RETURN            ${TRUE}

Confirm Order
    [Documentation]     Confirm a single order as completed
    [Arguments]         ${order_id}
    
    Should Not Be Empty    ${order_id}
    
    ${confirm_data}=    Create Dictionary    id=${order_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/confirm
    ...                 json=${confirm_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    RETURN            ${TRUE}

Delete Order
    [Documentation]     Delete an order from the system
    [Arguments]         ${order_id}
    
    Should Not Be Empty    ${order_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /orders/delete/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Create Multiple Test Orders
    [Documentation]     Creates a batch of test orders
    [Arguments]         ${count}=3
    
    @{order_ids}=       Create List
    FOR    ${i}    IN RANGE    ${count}
        ${order_data}=      Generate Unique Order Data    Bulk Order ${i+1}
        ${order_id}         ${response}=    Create Order    ${order_data}
        Append To List      ${order_ids}    ${order_id}
    END
    Set Global Variable  @{TEST_ORDER_IDS}    @{order_ids}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for bulk order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Multiple Orders Test
    [Documentation]     Test creating multiple orders in bulk
    [Tags]              create    positive
    
    Create Multiple Test Orders    3
    Should Not Be Empty    ${TEST_ORDER_IDS}
    Length Should Be    ${TEST_ORDER_IDS}    3
    
    Log                 Successfully created ${TEST_ORDER_IDS.__len__} orders: @{TEST_ORDER_IDS}

03 - Get All Orders Test
    [Documentation]     Test retrieving all created orders
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_IDS}" == "${EMPTY}"    Create Multiple Test Orders
    
    ${orders}=          Get All Orders    ${WAREHOUSE_ID}    NEW
    ${order_list}=      Set Variable    ${orders}
    Should Not Be Empty    ${order_list}
    
    ${found_ids}=       Create List
    FOR    ${order}    IN    @{order_list}
        Run Keyword If    "${order}[id]" in @{TEST_ORDER_IDS}    Append To List    ${found_ids}    ${order}[id]
    END
    Length Should Be    ${found_ids}    3
    
    Log                 Successfully retrieved all ${TEST_ORDER_IDS.__len__} orders

04 - Bulk Update Orders to Picking Test
    [Documentation]     Test bulk updating orders to PICKING status
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_IDS}" == "${EMPTY}"    Create Multiple Test Orders
    
    ${updated_orders}=  Bulk Update Orders    ${TEST_ORDER_IDS}    PICKING
    ${orders}=          Get All Orders    ${WAREHOUSE_ID}    PICKING
    ${order_list}=      Set Variable    ${orders}
    
    FOR    ${order}    IN    @{order_list}
        Run Keyword If    "${order}[id]" in @{TEST_ORDER_IDS}    Should Be Equal    ${order}[status]    PICKING
    END
    
    Log                 Successfully updated ${TEST_ORDER_IDS.__len__} orders to PICKING

05 - Check Picking for Multiple Orders Test
    [Documentation]     Test checking picking availability for all orders
    [Tags]              picking    positive
    
    Run Keyword If      "${TEST_ORDER_IDS}" == "${EMPTY}"    Create Multiple Test Orders
    
    ${result}=          Check Picking Orders    ${TEST_ORDER_IDS}
    Should Be True      ${result}
    
    Log                 Successfully checked picking availability for ${TEST_ORDER_IDS.__len__} orders

06 - Bulk Update Orders to Packaged Test
    [Documentation]     Test bulk updating orders to PACKAGED status
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_IDS}" == "${EMPTY}"    Create Multiple Test Orders
    
    ${updated_orders}=  Bulk Update Orders    ${TEST_ORDER_IDS}    PACKAGED
    ${orders}=          Get All Orders    ${WAREHOUSE_ID}    PACKAGED
    ${order_list}=      Set Variable    ${orders}
    
    FOR    ${order}    IN    @{order_list}
        Run Keyword If    "${order}[id]" in @{TEST_ORDER_IDS}    Should Be Equal    ${order}[status]    PACKAGED
    END
    
    Log                 Successfully updated ${TEST_ORDER_IDS.__len__} orders to PACKAGED

07 - Confirm One Order Test
    [Documentation]     Test confirming one order from the batch
    [Tags]              confirm    positive
    
    Run Keyword If      "${TEST_ORDER_IDS}" == "${EMPTY}"    Create Multiple Test Orders
    
    ${order_to_confirm}=    Set Variable    ${TEST_ORDER_IDS}[0]
    ${result}=          Confirm Order    ${order_to_confirm}
    Should Be True      ${result}
    
    ${orders}=          Get All Orders    ${WAREHOUSE_ID}    DELIVERED
    ${order_list}=      Set Variable    ${orders}
    FOR    ${order}    IN    @{order_list}
        Run Keyword If    "${order}[id]" == "${order_to_confirm}"    Should Be Equal    ${order}[status]    DELIVERED
    END
    
    Set Global Variable  ${CONFIRMED_ORDER_ID}    ${order_to_confirm}
    Log                 Successfully confirmed order: ${order_to_confirm} as DELIVERED

08 - Bulk Delete Remaining Orders Test
    [Documentation]     Test deleting remaining unconfirmed orders
    [Tags]              delete    positive
    
    Run Keyword If      "${TEST_ORDER_IDS}" == "${EMPTY}"    Create Multiple Test Orders
    
    @{remaining_orders}=    Create List
    FOR    ${order_id}    IN    @{TEST_ORDER_IDS}
        Run Keyword If    "${order_id}" != "${CONFIRMED_ORDER_ID}"    Append To List    ${remaining_orders}    ${order_id}
    END
    
    FOR    ${order_id}    IN    @{remaining_orders}
        ${result}=      Delete Order    ${order_id}
        Should Be True  ${result}
    END
    
    ${orders}=          Get All Orders    ${WAREHOUSE_ID}
    ${order_list}=      Set Variable    ${orders}
    FOR    ${order}    IN    @{order_list}
        Should Not Contain    ${remaining_orders}    ${order}[id]
    END
    
    Log                 Successfully deleted ${remaining_orders.__len__} remaining orders

09 - Verify Post-Cleanup Orders Test
    [Documentation]     Test that only the confirmed order remains
    [Tags]              retrieve    positive
    
    ${orders}=          Get All Orders    ${WAREHOUSE_ID}
    ${order_list}=      Set Variable    ${orders}
    ${found_confirmed}=    Set Variable    ${FALSE}
    
    FOR    ${order}    IN    @{order_list}
        Run Keyword If    "${order}[id]" == "${CONFIRMED_ORDER_ID}"    Set Variable    ${found_confirmed}    ${TRUE}
        Run Keyword If    "${order}[id]" != "${CONFIRMED_ORDER_ID}"    Fail    Unexpected order ${order}[id] found
    END
    Should Be True    ${found_confirmed}
    
    Log                 Verified only confirmed order ${CONFIRMED_ORDER_ID} remains

10 - Cleanup Test Environment
    [Documentation]     Clean up confirmed order
    [Tags]              cleanup
    
    Run Keyword If      "${CONFIRMED_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Order    ${CONFIRMED_ORDER_ID}
    
    Set Global Variable  @{TEST_ORDER_IDS}    ${EMPTY}
    Set Global Variable  ${CONFIRMED_ORDER_ID}    ${EMPTY}
    
    Log                 Test environment cleaned up successfully