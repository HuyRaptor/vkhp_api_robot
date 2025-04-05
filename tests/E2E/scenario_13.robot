*** Settings ***
Documentation     End-to-End Test Suite for Order with Inventory Validation and Partial Fulfillment in vKho API
...               Covers order creation, partial fulfillment, restocking, and completion
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
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Generate Unique Order Data
    [Documentation]     Generate unique data for order tests with two products
    [Arguments]         ${custom_name}=Partial Order
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     PART${timestamp}
    
    ${product1}=        Create Dictionary
    ...                 total=5
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=SKU1${timestamp}
    ${product2}=        Create Dictionary
    ...                 total=3
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=SKU2${timestamp}
    ${product_orders}=  Create List      ${product1}    ${product2}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=${custom_name} Customer
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}
    ...                 deliveryAdress=202 Partial Ln
    ...                 deliveryTime=2025-04-05T09:00:00.000Z
    ...                 driverName=Mike Ross
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
    [Arguments]         ${order_data}
    
    ${products}=        Create List
    FOR    ${product}    IN    @{order_data}[productOrders]
        ${item}=        Create Dictionary    sku=${product}[sku]    quantity=${product}[total]
        Append To List  ${products}    ${item}
    END
    
    ${check_data}=      Create Dictionary    warehouseId=${WAREHOUSE_ID}    products=${products}
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
    [Arguments]         ${order_id}
    
    Should Not Be Empty    ${order_id}
    
    ${package_data}=    Create Dictionary
    ...                 orderId=${order_id}
    ...                 warehouseId=${WAREHOUSE_ID}
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

Update Inventory
    [Documentation]     Update inventory stock for a product
    [Arguments]         ${inventory_id}    ${sku}    ${quantity}
    
    Should Not Be Empty    ${inventory_id}
    
    ${update_data}=     Create Dictionary
    ...                 id=${inventory_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 sku=${sku}
    ...                 quantity=${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /inventories/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    Dictionary Should Contain Key        ${json}    id
    
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

02 - Create Order Test
    [Documentation]     Test creating a new order with multiple products
    [Tags]              create    positive
    
    ${order_data}=      Generate Unique Order Data
    ${order_id}         ${response}=    Create Order    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}
    
    Log                 Successfully created order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

03 - Get Order Test
    [Documentation]     Test retrieving the created order
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Order Details    ${order}    ${TEST_ORDER_DATA}
    
    Log                 Successfully retrieved order: ${order}[code]

04 - Check Inventory Availability Test
    [Documentation]     Test checking inventory for order products
    [Tags]              inventory    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${availability}=    Check Inventory Availability    ${TEST_ORDER_DATA}
    Should Not Be Empty    ${availability}
    
    Log                 Successfully checked inventory availability for order: ${TEST_ORDER_ID}

05 - Update Order to Picking with Partial Fulfillment Test
    [Documentation]     Test updating order to PICKING with partial fulfillment
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PICKING
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 5}}, ${{"id": 2, "pickingQuantity": 0}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PICKING
    
    Log                 Successfully updated order to PICKING with partial fulfillment: ${TEST_ORDER_ID}

06 - Create Package for Partial Fulfillment Test
    [Documentation]     Test creating a package for partially fulfilled items
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${package_id}       ${response}=    Create Package    ${TEST_ORDER_ID}
    Should Not Be Empty    ${package_id}
    
    Set Global Variable  ${TEST_PACKAGE_ID}    ${package_id}
    
    Log                 Successfully created package: ${package_id} for partial order: ${TEST_ORDER_ID}

07 - Update Order to Packaged Test
    [Documentation]     Test updating order to PACKAGED for partial fulfillment
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PACKAGED
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 5}}, ${{"id": 2, "pickingQuantity": 0}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PACKAGED
    
    Log                 Successfully updated order to PACKAGED for partial fulfillment: ${TEST_ORDER_ID}

08 - Simulate Restocking Test
    [Documentation]     Test updating inventory to restock the unavailable product
    [Tags]              inventory    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${sku_to_restock}=  Set Variable    ${TEST_ORDER_DATA}[productOrders][1][sku]
    ${inventory_id}=    Set Variable    1    # Placeholder; assumes ID 1 exists or needs real ID from system
    ${updated_inventory}=  Update Inventory    ${inventory_id}    ${sku_to_restock}    10
    Should Be Equal As Integers    ${updated_inventory}[quantity]    10
    
    Set Global Variable  ${TEST_INVENTORY_ID}    ${inventory_id}
    
    Log                 Successfully restocked inventory for SKU: ${sku_to_restock}

09 - Update Order to Picking for Remaining Items Test
    [Documentation]     Test updating order to PICKING for remaining items
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PICKING
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 5}}, ${{"id": 2, "pickingQuantity": 3}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PICKING
    
    Log                 Successfully updated order to PICKING for remaining items: ${TEST_ORDER_ID}

10 - Update Order to Packaged for Full Fulfillment Test
    [Documentation]     Test updating order to PACKAGED for full fulfillment
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
    
    Log                 Successfully updated order to PACKAGED for full fulfillment: ${TEST_ORDER_ID}

11 - Confirm Order Test
    [Documentation]     Test confirming the order as fully fulfilled
    [Tags]              confirm    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${result}=          Confirm Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Should Be Equal     ${order}[status]    DELIVERED
    
    Log                 Successfully confirmed order: ${TEST_ORDER_ID} as DELIVERED

12 - Verify Final Order Test
    [Documentation]     Test retrieving the fully fulfilled order
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Should Be Equal     ${order}[status]    DELIVERED
    
    Log                 Successfully verified order as DELIVERED: ${TEST_ORDER_ID}

13 - Cleanup Test Environment
    [Documentation]     Clean up test order and package
    [Tags]              cleanup
    
    Run Keyword If      "${TEST_PACKAGE_ID}" != "${EMPTY}"
    ...                 Delete Package    ${TEST_PACKAGE_ID}
    Run Keyword If      "${TEST_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Order    ${TEST_ORDER_ID}
    
    Log                 Test environment cleaned up successfully