*** Settings ***
Documentation     End-to-End Test Suite for Order with Multi-Warehouse Fulfillment and Consolidated Delivery in vKho API
...               Covers multi-warehouse sourcing and single delivery consolidation
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_ID_1}       6
${WAREHOUSE_ID_2}       7
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_ORDER_ID}        ${EMPTY}
${TEST_ORDER_CODE}      ${EMPTY}
${TEST_ORDER_DATA}      ${EMPTY}
@{TEST_PACKAGE_IDS}     @{EMPTY}
${TEST_SKU_1}           ${EMPTY}
${TEST_SKU_2}           ${EMPTY}

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

Generate Multi-Warehouse Order Data
    [Documentation]     Generate unique data for order with items from multiple warehouses
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     MULTI${timestamp}
    
    ${sku1}=            Set Variable     SKU${timestamp}_1
    ${sku2}=            Set Variable     SKU${timestamp}_2
    ${product_order1}=  Create Dictionary
    ...                 total=4
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=${sku1}
    ${product_order2}=  Create Dictionary
    ...                 total=6
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=${sku2}
    ${product_orders}=  Create List      ${product_order1}    ${product_order2}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=Multi-Warehouse Customer
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}
    ...                 deliveryAdress=505 Multi St
    ...                 deliveryTime=2025-04-16T15:00:00.000Z
    ...                 driverName=Multi Driver
    ...                 warehouseId=${WAREHOUSE_ID_1}  # Primary warehouse
    ...                 productOrders=${product_orders}
    
    Set Global Variable  ${TEST_SKU_1}    ${sku1}
    Set Global Variable  ${TEST_SKU_2}    ${sku2}
    [Return]            ${order_data}

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
    [Return]            ${order_id}    ${json}

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
    
    [Return]            ${json}

Check Inventory Availability
    [Documentation]     Check inventory availability for a warehouse
    [Arguments]         ${warehouse_id}    ${products}
    
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
    
    [Return]            ${json}

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
    
    [Return]            ${json}

Create Package
    [Documentation]     Create a package for an order from a specific warehouse
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
    [Return]            ${package_id}    ${json}

Get Package By ID
    [Documentation]     Retrieve a specific package by ID
    [Arguments]         ${package_id}
    
    Should Not Be Empty    ${package_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /packages/get-one/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    Dictionary Should Contain Key        ${json}    id
    
    [Return]            ${json}

Confirm Order
    [Documentation]     Confirm the order as delivered
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
    
    [Return]            ${TRUE}

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
    
    [Return]            ${TRUE}

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
    
    [Return]            ${TRUE}

Assert Order Details
    [Documentation]     Verify order details match expected values
    [Arguments]         ${order}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${order}    Should Be Equal    ${order}[${key}]    ${expected_data}[${key}]
        ...    msg=Order ${key} value '${order}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Order
    [Documentation]     Creates a test order if one doesn't exist
    ${order_data}=      Generate Multi-Warehouse Order Data
    ${order_id}         ${response}=    Create Order    ${order_data}
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for multi-warehouse tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Multi-Warehouse Order Test
    [Documentation]     Test creating an order with items from multiple warehouses
    [Tags]              create    positive
    
    ${order_data}=      Generate Multi-Warehouse Order Data
    ${order_id}         ${response}=    Create Order    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}
    
    Log                 Successfully created multi-warehouse order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

03 - Get Order Test
    [Documentation]     Test retrieving the created order
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Order Details    ${order}    ${TEST_ORDER_DATA}
    
    Log                 Successfully retrieved order: ${order}[code]

04 - Check Inventory Availability Across Warehouses Test
    [Documentation]     Test checking inventory in two warehouses
    [Tags]              inventory    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${products_1}=      Create List    ${{"sku": "${TEST_SKU_1}", "quantity": 4}}
    ${products_2}=      Create List    ${{"sku": "${TEST_SKU_2}", "quantity": 6}}
    
    ${availability_1}=  Check Inventory Availability    ${WAREHOUSE_ID_1}    ${products_1}
    ${availability_2}=  Check Inventory Availability    ${WAREHOUSE_ID_2}    ${products_2}
    
    Should Not Be Empty    ${availability_1}
    Should Not Be Empty    ${availability_2}
    
    Log                 Successfully checked inventory availability for ${TEST_SKU_1} in warehouse ${WAREHOUSE_ID_1} and ${TEST_SKU_2} in warehouse ${WAREHOUSE_ID_2}

05 - Update Order to Picking for Multi-Warehouse Test
    [Documentation]     Test updating order to PICKING with multi-warehouse fulfillment
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PICKING
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 4}}, ${{"id": 2, "pickingQuantity": 6}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PICKING
    
    Log                 Successfully updated order to PICKING for multi-warehouse fulfillment: ${TEST_ORDER_ID}

06 - Create Packages from Each Warehouse Test
    [Documentation]     Test creating packages from two warehouses
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${package_id_1}     ${response_1}=    Create Package    ${TEST_ORDER_ID}    ${WAREHOUSE_ID_1}
    ${package_id_2}     ${response_2}=    Create Package    ${TEST_ORDER_ID}    ${WAREHOUSE_ID_2}
    
    Should Not Be Empty    ${package_id_1}
    Should Not Be Empty    ${package_id_2}
    
    ${package_ids}=     Create List    ${package_id_1}    ${package_id_2}
    Set Global Variable  ${TEST_PACKAGE_IDS}    ${package_ids}
    
    Log                 Successfully created packages: ${package_id_1} from warehouse ${WAREHOUSE_ID_1} and ${package_id_2} from warehouse ${WAREHOUSE_ID_2}

07 - Update Order to Packaged Test
    [Documentation]     Test updating order to PACKAGED after multi-warehouse packing
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PACKAGED
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 4}}, ${{"id": 2, "pickingQuantity": 6}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PACKAGED
    
    Log                 Successfully updated order to PACKAGED: ${TEST_ORDER_ID}

08 - Confirm Consolidated Delivery Test
    [Documentation]     Test confirming the order as delivered with consolidated packages
    [Tags]              confirm    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${result}=          Confirm Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Should Be Equal     ${order}[status]    DELIVERED
    
    Log                 Successfully confirmed consolidated delivery for order: ${TEST_ORDER_ID}

09 - Verify Final Order and Packages Test
    [Documentation]     Test retrieving order and packages after consolidated delivery
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    Run Keyword If      "${TEST_PACKAGE_IDS.__len__()}" == "0"    Create Packages from Each Warehouse Test
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    ${package_1}=       Get Package By ID    ${TEST_PACKAGE_IDS}[0]
    ${package_2}=       Get Package By ID    ${TEST_PACKAGE_IDS}[1]
    
    Should Be Equal     ${order}[status]    DELIVERED
    Should Be Equal     ${package_1}[orderId]    ${TEST_ORDER_ID}
    Should Be Equal     ${package_2}[orderId]    ${TEST_ORDER_ID}
    
    Log                 Successfully verified delivered order ${TEST_ORDER_ID} with packages ${TEST_PACKAGE_IDS}

10 - Cleanup Test Environment
    [Documentation]     Clean up test order and packages
    [Tags]              cleanup
    
    FOR    ${package_id}    IN    @{TEST_PACKAGE_IDS}
        Delete Package    ${package_id}
    END
    
    Run Keyword If      "${TEST_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Order    ${TEST_ORDER_ID}
    
    Log                 Test environment cleaned up successfully