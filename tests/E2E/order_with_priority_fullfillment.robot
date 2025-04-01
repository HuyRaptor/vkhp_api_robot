*** Settings ***
Documentation     End-to-End Test Suite for Order with Expedited Shipping and Priority Fulfillment in vKho API
...               Covers priority order creation, expedited processing, and delivery
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
${TEST_ORDER_CODE}      ${EMPTY}
${TEST_ORDER_DATA}      ${EMPTY}
${TEST_PACKAGE_ID}      ${EMPTY}

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

Generate Expedited Order Data
    [Documentation]     Generate unique data for an expedited order
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     EXP${timestamp}
    
    ${current_time}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%S.000Z
    ${delivery_time}=   Add Time To Date    ${current_time}    2 hours    result_format=%Y-%m-%dT%H:%M:%S.000Z
    
    ${sku}=             Set Variable     SKU${timestamp}
    ${product_order}=   Create Dictionary
    ...                 total=3
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=${sku}
    ${product_orders}=  Create List      ${product_order}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=Expedited Customer
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}
    ...                 deliveryAdress=707 Rush Ln
    ...                 deliveryTime=${delivery_time}
    ...                 driverName=Express Driver
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${product_orders}
    
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
    [Documentation]     Create a package for the expedited order
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
    [Documentation]     Creates a test expedited order if one doesn't exist
    ${order_data}=      Generate Expedited Order Data
    ${order_id}         ${response}=    Create Order    ${order_data}
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for expedited shipping tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Expedited Order Test
    [Documentation]     Test creating an expedited order
    [Tags]              create    positive
    
    ${order_data}=      Generate Expedited Order Data
    ${order_id}         ${response}=    Create Order    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}
    
    Log                 Successfully created expedited order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

03 - Get Order Test
    [Documentation]     Test retrieving the expedited order
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Order Details    ${order}    ${TEST_ORDER_DATA}
    
    Log                 Successfully retrieved expedited order: ${order}[code]

04 - Check Inventory Availability Test
    [Documentation]     Test checking inventory availability for expedited order
    [Tags]              inventory    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${availability}=    Check Inventory Availability    ${WAREHOUSE_ID}    ${TEST_ORDER_DATA}
    Should Not Be Empty    ${availability}
    
    Log                 Successfully checked inventory availability for expedited order: ${TEST_ORDER_ID}

05 - Update Order to Priority Picking Test
    [Documentation]     Test updating expedited order to PICKING with priority
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PICKING
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 3}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PICKING
    
    Log                 Successfully updated expedited order to PICKING: ${TEST_ORDER_ID}

06 - Create Priority Package Test
    [Documentation]     Test creating a package for the expedited order
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${package_id}       ${response}=    Create Package    ${TEST_ORDER_ID}
    Should Not Be Empty    ${package_id}
    
    Set Global Variable  ${TEST_PACKAGE_ID}    ${package_id}
    
    Log                 Successfully created priority package: ${package_id} for order: ${TEST_ORDER_ID}

07 - Update Order to Packaged Test
    [Documentation]     Test updating expedited order to PACKAGED
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PACKAGED
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 3}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PACKAGED
    
    Log                 Successfully updated expedited order to PACKAGED: ${TEST_ORDER_ID}

08 - Confirm Expedited Delivery Test
    [Documentation]     Test confirming the expedited order as delivered
    [Tags]              confirm    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${result}=          Confirm Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Should Be Equal     ${order}[status]    DELIVERED
    
    Log                 Successfully confirmed expedited order as DELIVERED: ${TEST_ORDER_ID}

09 - Verify Final Order and Package Test
    [Documentation]     Test retrieving expedited order and package after delivery
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Priority Package Test
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    ${package}=         Get Package By ID    ${TEST_PACKAGE_ID}
    
    Should Be Equal     ${order}[status]    DELIVERED
    Should Not Be Empty    ${package}[orderId]
    
    Log                 Successfully verified expedited order ${TEST_ORDER_ID} and package ${TEST_PACKAGE_ID}

10 - Cleanup Test Environment
    [Documentation]     Clean up test order and package
    [Tags]              cleanup
    
    Run Keyword If      "${TEST_PACKAGE_ID}" != "${EMPTY}"
    ...                 Delete Package    ${TEST_PACKAGE_ID}
    Run Keyword If      "${TEST_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Order    ${TEST_ORDER_ID}
    
    Log                 Test environment cleaned up successfully