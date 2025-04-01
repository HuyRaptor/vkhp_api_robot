*** Settings ***
Documentation     End-to-End Test Suite for Order with Split Fulfillment Across Multiple Warehouses in vKho API
...               Covers order creation, split fulfillment, and confirmation
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_1_ID}       6
${WAREHOUSE_2_ID}       7
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_ORDER_ID}        ${EMPTY}
${TEST_ORDER_CODE}      ${EMPTY}
${TEST_ORDER_DATA}      ${EMPTY}
@{TEST_PACKAGE_IDS}     @{EMPTY}
${SKU_1}                ${EMPTY}
${SKU_2}                ${EMPTY}

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
    [Documentation]     Generate unique data for order with multiple items
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     SPLIT${timestamp}
    
    ${sku1}=            Set Variable     SKU${timestamp}_1
    ${sku2}=            Set Variable     SKU${timestamp}_2
    ${product_order1}=  Create Dictionary
    ...                 total=5
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=${sku1}
    ${product_order2}=  Create Dictionary
    ...                 total=3
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=${sku2}
    ${product_orders}=  Create List      ${product_order1}    ${product_order2}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=Split Order Customer
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}
    ...                 deliveryAdress=808 Split Way
    ...                 deliveryTime=2025-04-11T15:00:00.000Z
    ...                 driverName=Split Driver
    ...                 warehouseId=${WAREHOUSE_1_ID}
    ...                 productOrders=${product_orders}
    
    Set Global Variable  ${SKU_1}    ${sku1}
    Set Global Variable  ${SKU_2}    ${sku2}
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

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    
    Should Not Be Empty    ${order_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}

Check Inventory Availability
    [Documentation]     Check inventory availability for order products
    [Arguments]         ${warehouse_id}    ${order_data}
    
    ${products}=        Create List
    FOR    ${product}    IN    @{order_data}[productOrders]
        ${item}=        Create Dictionary    sku=${product}[sku]    quantity=${product}[total]
        Append To List  ${products}    ${item}
    END
    
    ${check_data}=      Create Dictionary    warehouseId=${warehouse_id}    products=${products}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventories/check-available
    ...                 json=${check_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    
    RETURN            ${json}

Update Order
    [Documentation]     Update an existing order
    [Arguments]         ${order_id}    ${update_data}
    
    Should Not Be Empty    ${order_id}
    Dictionary Should Contain Key    ${update_data}    id
    Should Be Equal     ${update_data}[id]    ${order_id}
    
    Dictionary Should Contain Key    ${update_data}    boothCode
    Dictionary Should Contain Key    ${update_data}    deliveryAdress
    Dictionary Should Contain Key    ${update_data}    status
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}

Create Package
    [Documentation]     Create a package for the order
    [Arguments]         ${order_id}    ${warehouse_id}
    
    Should Not Be Empty    ${order_id}
    
    ${package_data}=    Create Dictionary
    ...                 orderId=${order_id}
    ...                 warehouseId=${warehouse_id}
    ...                 zoneId=1
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /packages/create
    ...                 json=${package_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    ${package_id}=      Convert To String    ${json}[id]
    RETURN            ${package_id}    ${json}

Get All Packages
    [Documentation]     Retrieve all packages
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /packages/get-all
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    
    RETURN            ${json}

Confirm Order
    [Documentation]     Confirm the order as completed
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

Delete Package
    [Documentation]     Delete a package from the system
    [Arguments]         ${package_id}
    
    Should Not Be Empty    ${package_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /packages/delete/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Assert Order Details
    [Documentation]     Verify order details match expected values
    [Arguments]         ${order}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${order}    Should Be Equal    ${order}[${key}]    ${expected_data}[${key}]
        ...    msg=Order ${key} value '${order}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Order
    [Documentation]     Creates a test order if one doesn't exist
    ${order_data}=      Generate Unique Order Data
    ${order_id}         ${response}=    Create Order    ${order_data}
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Order with Multiple Items Test
    [Documentation]     Test creating a new order with multiple items
    [Tags]              create    positive
    
    ${order_data}=      Generate Unique Order Data
    ${order_id}         ${response}=    Create Order    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    Should Be Equal As Integers    ${response}[warehouseId]    ${WAREHOUSE_1_ID}
    
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}
    
    Log                 Successfully created order with multiple items: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

03 - Get Order Test
    [Documentation]     Test retrieving the created order
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Order Details    ${order}    ${TEST_ORDER_DATA}
    
    Log                 Successfully retrieved order: ${order}[code]

04 - Check Inventory in Initial Warehouse Test
    [Documentation]     Test checking inventory in Warehouse 1
    [Tags]              inventory    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${availability}=    Check Inventory Availability    ${WAREHOUSE_1_ID}    ${TEST_ORDER_DATA}
    Should Not Be Empty    ${availability}
    
    Log                 Successfully checked inventory availability in Warehouse ${WAREHOUSE_1_ID} for order: ${TEST_ORDER_ID}

05 - Update Order to Picking in Warehouse 1 Test
    [Documentation]     Test updating order to PICKING for available items in Warehouse 1
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PICKING
    ...                 warehouseId=${WAREHOUSE_1_ID}
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 5}} ]}  # Partial picking for SKU_1
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PICKING
    
    Log                 Successfully updated order to PICKING in Warehouse ${WAREHOUSE_1_ID}: ${TEST_ORDER_ID}

06 - Create Package in Warehouse 1 Test
    [Documentation]     Test creating a package in Warehouse 1
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${package_id}       ${response}=    Create Package    ${TEST_ORDER_ID}    ${WAREHOUSE_1_ID}
    Should Not Be Empty    ${package_id}
    Should Be Equal As Integers    ${response}[warehouseId]    ${WAREHOUSE_1_ID}
    
    Append To List      ${TEST_PACKAGE_IDS}    ${package_id}
    
    Log                 Successfully created package ${package_id} in Warehouse ${WAREHOUSE_1_ID} for order: ${TEST_ORDER_ID}

07 - Update Order to Split Status Test
    [Documentation]     Test updating order to SPLIT status for remaining items
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=SPLIT    # Simulated status; adjust if not supported
    ...                 warehouseId=${WAREHOUSE_2_ID}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    SPLIT
    
    Log                 Successfully updated order to SPLIT status for Warehouse ${WAREHOUSE_2_ID}: ${TEST_ORDER_ID}

08 - Check Inventory in Second Warehouse Test
    [Documentation]     Test checking inventory in Warehouse 2
    [Tags]              inventory    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${availability}=    Check Inventory Availability    ${WAREHOUSE_2_ID}    ${TEST_ORDER_DATA}
    Should Not Be Empty    ${availability}
    
    Log                 Successfully checked inventory availability in Warehouse ${WAREHOUSE_2_ID} for order: ${TEST_ORDER_ID}

09 - Update Order to Picking in Warehouse 2 Test
    [Documentation]     Test updating order to PICKING for remaining items in Warehouse 2
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PICKING
    ...                 warehouseId=${WAREHOUSE_2_ID}
    ...                 updateProductOrder=${[ ${{"id": 2, "pickingQuantity": 3}} ]}  # Picking for SKU_2
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PICKING
    
    Log                 Successfully updated order to PICKING in Warehouse ${WAREHOUSE_2_ID}: ${TEST_ORDER_ID}

10 - Create Package in Warehouse 2 Test
    [Documentation]     Test creating a package in Warehouse 2
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${package_id}       ${response}=    Create Package    ${TEST_ORDER_ID}    ${WAREHOUSE_2_ID}
    Should Not Be Empty    ${package_id}
    Should Be Equal As Integers    ${response}[warehouseId]    ${WAREHOUSE_2_ID}
    
    Append To List      ${TEST_PACKAGE_IDS}    ${package_id}
    
    Log                 Successfully created package ${package_id} in Warehouse ${WAREHOUSE_2_ID} for order: ${TEST_ORDER_ID}

11 - Update Order to Packaged Test
    [Documentation]     Test updating order to PACKAGED after split fulfillment
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PACKAGED
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 5}}, ${{"id": 2, "pickingQuantity": 3}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PACKAGED
    
    Log                 Successfully updated order to PACKAGED after split fulfillment: ${TEST_ORDER_ID}

12 - Confirm Order Test
    [Documentation]     Test confirming the split order as delivered
    [Tags]              confirm    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${result}=          Confirm Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Should Be Equal     ${order}[status]    DELIVERED
    
    Log                 Successfully confirmed split order as DELIVERED: ${TEST_ORDER_ID}

13 - Verify Final Order and Packages Test
    [Documentation]     Test retrieving order and packages after split fulfillment
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    Run Keyword If      "${TEST_PACKAGE_IDS.__len__()}" < "2"    Create Package in Warehouse 1 Test
    Run Keyword If      "${TEST_PACKAGE_IDS.__len__()}" < "2"    Create Package in Warehouse 2 Test
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    ${packages}=        Get All Packages
    
    Should Be Equal     ${order}[status]    DELIVERED
    ${package_count}=   Get Length    ${packages}
    Should Be True      ${package_count} >= 2
    
    ${warehouse_1_found}=  Set Variable    ${FALSE}
    ${warehouse_2_found}=  Set Variable    ${FALSE}
    FOR    ${package}    IN    @{packages}
        ${package_id}=  Convert To String    ${package}[id]
        Run Keyword If  "${package_id}" in ${TEST_PACKAGE_IDS} and ${package}[warehouseId] == ${WAREHOUSE_1_ID}
        ...             Set Variable    ${warehouse_1_found}    ${TRUE}
        Run Keyword If  "${package_id}" in ${TEST_PACKAGE_IDS} and ${package}[warehouseId] == ${WAREHOUSE_2_ID}
        ...             Set Variable    ${warehouse_2_found}    ${TRUE}
    END
    Should Be True      ${warehouse_1_found} and ${warehouse_2_found}
    
    Log                 Successfully verified delivered order ${TEST_ORDER_ID} with packages from Warehouses ${WAREHOUSE_1_ID} and ${WAREHOUSE_2_ID}

14 - Cleanup Test Environment
    [Documentation]     Clean up test order and packages
    [Tags]              cleanup
    
    FOR    ${package_id}    IN    @{TEST_PACKAGE_IDS}
        Delete Package    ${package_id}
    END
    
    Run Keyword If      "${TEST_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Order    ${TEST_ORDER_ID}
    
    Set Global Variable  ${TEST_PACKAGE_IDS}   @{EMPTY}
    Log                 Test environment cleaned up successfully