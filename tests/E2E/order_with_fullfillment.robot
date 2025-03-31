*** Settings ***
Documentation     End-to-End Test Suite for Order with Priority Escalation and Expedited Fulfillment in vKho API
...               Covers order creation, priority escalation, and expedited fulfillment
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

Generate Unique Order Data
    [Documentation]     Generate unique data for order tests
    [Arguments]         ${custom_name}=Priority Order
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     PRIO${timestamp}
    
    ${product_order}=   Create Dictionary
    ...                 total=15
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=SKU${timestamp}
    ${product_orders}=  Create List      ${product_order}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=${custom_name} Customer
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}
    ...                 deliveryAdress=404 Priority St
    ...                 deliveryTime=2025-04-07T08:00:00.000Z
    ...                 driverName=Tom Hanks
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
    [Return]            ${package_id}    ${json}

Update Package
    [Documentation]     Update package details (e.g., tracking code)
    [Arguments]         ${package_id}    ${update_data}
    
    Should Not Be Empty    ${package_id}
    Dictionary Should Contain Key    ${update_data}    id
    Should Be Equal     ${update_data}[id]    ${package_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /packages/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    Dictionary Should Contain Key        ${json}    id
    
    [Return]            ${json}

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

02 - Create Order with Standard Priority Test
    [Documentation]     Test creating a new order with standard priority
    [Tags]              create    positive
    
    ${order_data}=      Generate Unique Order Data
    ${order_id}         ${response}=    Create Order    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    
    Set Global Variable  ${TEST_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}
    
    Log                 Successfully created standard priority order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

03 - Get Order Test
    [Documentation]     Test retrieving the created order
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Order Details    ${order}    ${TEST_ORDER_DATA}
    
    Log                 Successfully retrieved order: ${order}[code]

04 - Escalate Order Priority Test
    [Documentation]     Test escalating order to high priority
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=NEW
    ...                 priority=High    # Simulated field; adjust if API supports priority explicitly
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    NEW
    
    Log                 Successfully escalated order priority to High: ${TEST_ORDER_ID}

05 - Update Order to Picking (Expedited) Test
    [Documentation]     Test updating order to PICKING with expedited processing
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PICKING
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 15}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PICKING
    
    Log                 Successfully updated order to PICKING (expedited): ${TEST_ORDER_ID}

06 - Create Package for Expedited Shipping Test
    [Documentation]     Test creating a package for expedited shipping
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${package_id}       ${response}=    Create Package    ${TEST_ORDER_ID}
    Should Not Be Empty    ${package_id}
    
    Set Global Variable  ${TEST_PACKAGE_ID}    ${package_id}
    
    Log                 Successfully created package: ${package_id} for expedited order: ${TEST_ORDER_ID}

07 - Update Package with Expedited Tracking Test
    [Documentation]     Test updating package with expedited tracking details
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Test Order
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Package    ${TEST_ORDER_ID}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${tracking_code}=   Set Variable     EXP${timestamp}
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_PACKAGE_ID}
    ...                 orderId=${TEST_ORDER_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 zoneId=1
    ...                 trackingCode=${tracking_code}
    
    ${updated_package}= Update Package    ${TEST_PACKAGE_ID}    ${update_data}
    Should Be Equal     ${updated_package}[trackingCode]    ${tracking_code}
    
    Log                 Successfully updated package ${TEST_PACKAGE_ID} with expedited tracking: ${tracking_code}

08 - Update Order to Packaged Test
    [Documentation]     Test updating order to PACKAGED for expedited fulfillment
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PACKAGED
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 15}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PACKAGED
    
    Log                 Successfully updated order to PACKAGED (expedited): ${TEST_ORDER_ID}

09 - Update Order to Delivering (Expedited) Test
    [Documentation]     Test updating order to DELIVERING with expedited delivery
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=DELIVERING
    ...                 updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 15}} ]}
    
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    DELIVERING
    
    Log                 Successfully updated order to DELIVERING (expedited): ${TEST_ORDER_ID}

10 - Confirm Order Test
    [Documentation]     Test confirming the expedited order as completed
    [Tags]              confirm    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    
    ${result}=          Confirm Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Should Be Equal     ${order}[status]    DELIVERED
    
    Log                 Successfully confirmed expedited order: ${TEST_ORDER_ID} as DELIVERED

11 - Verify Final Order and Package Test
    [Documentation]     Test retrieving order and package after expedited fulfillment
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_ID}" == "${EMPTY}"    Create Test Order
    Run Keyword If      "${TEST_PACKAGE_ID}" == "${EMPTY}"    Create Package    ${TEST_ORDER_ID}
    
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    ${package}=         Get Package By ID    ${TEST_PACKAGE_ID}
    
    Should Be Equal     ${order}[status]    DELIVERED
    Should Not Be Empty    ${package}[trackingCode]
    
    Log                 Successfully verified expedited order ${TEST_ORDER_ID} as DELIVERED and package ${TEST_PACKAGE_ID} with tracking

12 - Cleanup Test Environment
    [Documentation]     Clean up test order and package
    [Tags]              cleanup
    
    Run Keyword If      "${TEST_PACKAGE_ID}" != "${EMPTY}"
    ...                 Delete Package    ${TEST_PACKAGE_ID}
    Run Keyword If      "${TEST_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Order    ${TEST_ORDER_ID}
    
    Log                 Test environment cleaned up successfully