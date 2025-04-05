*** Settings ***
Documentation     End-to-End Test Suite for Order with Bulk Processing and Batch Confirmation in vKho API
...               Covers bulk order creation, processing, and batch confirmation
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
    [Documentation]     Generate unique data for a single order
    [Arguments]         ${index}    ${custom_name}=Bulk Order
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     BULK${timestamp}_${index}
    
    ${product_order}=   Create Dictionary
    ...                 total=8
    ...                 boothCode=BOOTH${timestamp}_${index}
    ...                 sku=SKU${timestamp}_${index}
    ${product_orders}=  Create List      ${product_order}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=${custom_name} ${index} Customer
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}_${index}
    ...                 deliveryAdress=606 Bulk Ave ${index}
    ...                 deliveryTime=2025-04-09T10:00:00.000Z
    ...                 driverName=Driver ${index}
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
    Create File         ${RESULTS_DIR}${/}order_create_${timestamp}_${order_data}[code].json    ${response.text}
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    Dictionary Should Contain Key        ${json}    id
    
    ${order_id}=        Convert To String    ${json}[id]
    RETURN            ${order_id}    ${json}

Get All Orders
    [Documentation]     Retrieve all orders
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-all
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
    [Documentation]     Confirm an order as completed
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

Create Bulk Test Orders
    [Documentation]     Creates a batch of test orders if none exist
    @{order_ids}=       Create List
    @{order_codes}=     Create List
    @{order_data}=      Create List
    
    FOR    ${index}    IN RANGE    ${BULK_SIZE}
        ${data}=        Generate Unique Order Data    ${index}
        ${order_id}     ${response}=    Create Order    ${data}
        Append To List  ${order_ids}    ${order_id}
        Append To List  ${order_codes}  ${response}[code]
        Append To List  ${order_data}   ${data}
    END
    
    Set Global Variable  ${TEST_ORDER_IDS}     ${order_ids}
    Set Global Variable  ${TEST_ORDER_CODES}   ${order_codes}
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for bulk order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Bulk Orders Test
    [Documentation]     Test creating multiple orders in bulk
    [Tags]              create    positive
    
    Create Bulk Test Orders
    Should Be Equal As Integers    ${TEST_ORDER_IDS.__len__()}    ${BULK_SIZE}
    
    FOR    ${index}    IN RANGE    ${BULK_SIZE}
        Should Not Be Empty    ${TEST_ORDER_IDS}[${index}]
        Should Be Equal     ${TEST_ORDER_CODES}[${index}]    ${TEST_ORDER_DATA}[${index}][code]
    END
    
    Log                 Successfully created ${BULK_SIZE} bulk orders: ${TEST_ORDER_CODES}

03 - Get All Orders Test
    [Documentation]     Test retrieving all created orders
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Bulk Test Orders
    
    ${orders}=          Get All Orders
    ${order_count}=     Get Length    ${orders}
    Should Be True      ${order_count} >= ${BULK_SIZE}
    
    FOR    ${order}    IN    @{orders}
        ${order_id}=    Convert To String    ${order}[id]
        Run Keyword If  "${order_id}" in ${TEST_ORDER_IDS}
        ...             Assert Order Details    ${order}    ${TEST_ORDER_DATA}[${TEST_ORDER_IDS.index("${order_id}")}]
    END
    
    Log                 Successfully retrieved all bulk orders

04 - Update Orders to Picking Test
    [Documentation]     Test updating all orders to PICKING status in bulk
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Bulk Test Orders
    
    FOR    ${index}    IN RANGE    ${BULK_SIZE}
        ${update_data}=  Create Dictionary
        ...              id=${TEST_ORDER_IDS}[${index}]
        ...              boothCode=${TEST_ORDER_DATA}[${index}][boothCode]
        ...              deliveryAdress=${TEST_ORDER_DATA}[${index}][deliveryAdress]
        ...              deliveryTime=${TEST_ORDER_DATA}[${index}][deliveryTime]
        ...              driverName=${TEST_ORDER_DATA}[${index}][driverName]
        ...              status=PICKING
        ...              updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 8}} ]}
        
        ${updated_order}=  Update Order    ${TEST_ORDER_IDS}[${index}]    ${update_data}
        Should Be Equal    ${updated_order}[status]    PICKING
    END
    
    Log                 Successfully updated ${BULK_SIZE} orders to PICKING

05 - Create Packages for All Orders Test
    [Documentation]     Test creating packages for all orders in bulk
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Bulk Test Orders
    
    @{package_ids}=     Create List
    FOR    ${order_id}    IN    @{TEST_ORDER_IDS}
        ${package_id}   ${response}=    Create Package    ${order_id}
        Should Not Be Empty    ${package_id}
        Append To List  ${package_ids}    ${package_id}
    END
    
    Set Global Variable  ${TEST_PACKAGE_IDS}    ${package_ids}
    Should Be Equal As Integers    ${TEST_PACKAGE_IDS.__len__()}    ${BULK_SIZE}
    
    Log                 Successfully created ${BULK_SIZE} packages for bulk orders

06 - Update Orders to Packaged Test
    [Documentation]     Test updating all orders to PACKAGED status in bulk
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Bulk Test Orders
    
    FOR    ${index}    IN RANGE    ${BULK_SIZE}
        ${update_data}=  Create Dictionary
        ...              id=${TEST_ORDER_IDS}[${index}]
        ...              boothCode=${TEST_ORDER_DATA}[${index}][boothCode]
        ...              deliveryAdress=${TEST_ORDER_DATA}[${index}][deliveryAdress]
        ...              deliveryTime=${TEST_ORDER_DATA}[${index}][deliveryTime]
        ...              driverName=${TEST_ORDER_DATA}[${index}][driverName]
        ...              status=PACKAGED
        ...              updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 8}} ]}
        
        ${updated_order}=  Update Order    ${TEST_ORDER_IDS}[${index}]    ${update_data}
        Should Be Equal    ${updated_order}[status]    PACKAGED
    END
    
    Log                 Successfully updated ${BULK_SIZE} orders to PACKAGED

07 - Batch Confirm All Orders Test
    [Documentation]     Test confirming all orders in a batch operation
    [Tags]              confirm    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Bulk Test Orders
    
    FOR    ${order_id}    IN    @{TEST_ORDER_IDS}
        ${result}=       Confirm Order    ${order_id}
        Should Be True   ${result}
    END
    
    ${orders}=          Get All Orders
    FOR    ${order}    IN    @{orders}
        ${order_id}=    Convert To String    ${order}[id]
        Run Keyword If  "${order_id}" in ${TEST_ORDER_IDS}
        ...             Should Be Equal    ${order}[status]    DELIVERED
    END
    
    Log                 Successfully batch confirmed ${BULK_SIZE} orders as DELIVERED

08 - Verify Final Orders and Packages Test
    [Documentation]     Test retrieving all orders and packages after batch confirmation
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Bulk Test Orders
    Run Keyword If      "${TEST_PACKAGE_IDS.__len__()}" == "0"  Create Packages for All Orders Test
    
    ${orders}=          Get All Orders
    ${packages}=        Get All Packages
    
    ${order_count}=     Get Length    ${orders}
    ${package_count}=   Get Length    ${packages}
    Should Be True      ${order_count} >= ${BULK_SIZE}
    Should Be True      ${package_count} >= ${BULK_SIZE}
    
    FOR    ${order}    IN    @{orders}
        ${order_id}=    Convert To String    ${order}[id]
        Run Keyword If  "${order_id}" in ${TEST_ORDER_IDS}
        ...             Should Be Equal    ${order}[status]    DELIVERED
    END
    
    FOR    ${package}    IN    @{packages}
        ${package_id}=  Convert To String    ${package}[id]
        Run Keyword If  "${package_id}" in ${TEST_PACKAGE_IDS}
        ...             Should Not Be Empty    ${package}[orderId]
    END
    
    Log                 Successfully verified ${BULK_SIZE} delivered orders and associated packages

09 - Cleanup Test Environment
    [Documentation]     Clean up test orders and packages
    [Tags]              cleanup
    
    FOR    ${package_id}    IN    @{TEST_PACKAGE_IDS}
        Delete Package    ${package_id}
    END
    
    FOR    ${order_id}    IN    @{TEST_ORDER_IDS}
        Delete Order    ${order_id}
    END
    
    Set Global Variable  ${TEST_ORDER_IDS}     @{EMPTY}
    Set Global Variable  ${TEST_ORDER_CODES}   @{EMPTY}
    Set Global Variable  ${TEST_ORDER_DATA}    @{EMPTY}
    Set Global Variable  ${TEST_PACKAGE_IDS}   @{EMPTY}
    
    Log                 Test environment cleaned up successfully