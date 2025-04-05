*** Settings ***
Documentation     End-to-End Test Suite for Order with Bulk Processing and Batch Fulfillment in vKho API
...               Covers bulk order creation, batch processing, and fulfillment
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

Generate Bulk Order Data
    [Documentation]     Generate unique data for bulk orders
    [Arguments]         ${count}=3
    
    ${bulk_orders}=     Create List
    ${timestamp}=       Evaluate         int(time.time())    time
    
    ${sku1}=            Set Variable     SKU${timestamp}_1
    ${sku2}=            Set Variable     SKU${timestamp}_2
    Set Global Variable  ${TEST_SKU_1}    ${sku1}
    Set Global Variable  ${TEST_SKU_2}    ${sku2}
    
    FOR    ${index}    IN RANGE    ${count}
        ${order_code}=  Set Variable     BULK${timestamp}_${index}
        ${product_order1}=  Create Dictionary
        ...                 total=2
        ...                 boothCode=BOOTH${timestamp}
        ...                 sku=${sku1}
        ${product_order2}=  Create Dictionary
        ...                 total=3
        ...                 boothCode=BOOTH${timestamp}
        ...                 sku=${sku2}
        ${product_orders}=  Create List      ${product_order1}    ${product_order2}
        
        ${order_data}=  Create Dictionary
        ...             nameCustomer=Batch Customer ${index}
        ...             code=${order_code}
        ...             boothCode=BOOTH${timestamp}
        ...             deliveryAdress=404 Batch Ln
        ...             deliveryTime=2025-04-15T12:00:00.000Z
        ...             driverName=Batch Driver
        ...             warehouseId=${WAREHOUSE_ID}
        ...             productOrders=${product_orders}
        
        Append To List  ${bulk_orders}    ${order_data}
    END
    
    RETURN            ${bulk_orders}

Create Bulk Orders
    [Documentation]     Create multiple orders in bulk and return their IDs
    [Arguments]         ${bulk_orders}
    
    ${order_ids}=       Create List
    ${order_codes}=     Create List
    ${order_data_list}= Create List
    
    FOR    ${order_data}    IN    @{bulk_orders}
        Dictionary Should Contain Key    ${order_data}    code
        Dictionary Should Contain Key    ${order_data}    warehouseId
        
        ${headers}=     Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
        
        ${response}=    POST On Session
        ...             vkho
        ...             /orders/create
        ...             json=${order_data}
        ...             headers=${headers}
        ...             expected_status=201
        
        ${timestamp}=   Evaluate         int(time.time())    time
        Create File     ${RESULTS_DIR}${/}order_create_${timestamp}_${order_data}[code].json    ${response.text}
        
        ${json}=        Evaluate         json.loads('''${response.text}''')    json
        Should Not Be Empty    ${json}
        Dictionary Should Contain Key        ${json}    id
        
        ${order_id}=    Convert To String    ${json}[id]
        Append To List  ${order_ids}    ${order_id}
        Append To List  ${order_codes}  ${order_data}[code]
        Append To List  ${order_data_list}  ${order_data}
    END
    
    RETURN            ${order_ids}    ${order_codes}    ${order_data_list}

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

Check Inventory Availability For Batch
    [Documentation]     Check inventory availability for all bulk orders
    [Arguments]         ${warehouse_id}    ${bulk_orders}
    
    ${products}=        Create Dictionary
    FOR    ${order_data}    IN    @{bulk_orders}
        FOR    ${product}    IN    @{order_data}[productOrders]
            ${sku}=         ${product}[sku]
            ${quantity}=    ${product}[total]
            ${existing}=    Get From Dictionary    ${products}    ${sku}    0
            ${new_total}=   Evaluate    ${existing} + ${quantity}
            Set To Dictionary    ${products}    ${sku}    ${new_total}
        END
    END
    
    ${product_list}=    Create List
    FOR    ${sku}    IN    @{products.keys()}
        ${item}=        Create Dictionary    sku=${sku}    quantity=${products}[${sku}]
        Append To List  ${product_list}    ${item}
    END
    
    ${check_data}=      Create Dictionary    warehouseId=${warehouse_id}    products=${product_list}
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
    [Documentation]     Create a package for an order
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
    
    RETURN            ${json}

Confirm Order
    [Documentation]     Confirm an order as delivered
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

Create Test Bulk Orders
    [Documentation]     Creates a batch of test orders if none exist
    ${bulk_orders}=     Generate Bulk Order Data
    ${order_ids}        ${order_codes}    ${order_data_list}=    Create Bulk Orders    ${bulk_orders}
    Set Global Variable  ${TEST_ORDER_IDS}     ${order_ids}
    Set Global Variable  ${TEST_ORDER_CODES}   ${order_codes}
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data_list}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for bulk order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Bulk Orders Test
    [Documentation]     Test creating multiple orders in bulk
    [Tags]              create    positive
    
    ${bulk_orders}=     Generate Bulk Order Data
    ${order_ids}        ${order_codes}    ${order_data_list}=    Create Bulk Orders    ${bulk_orders}
    
    Should Not Be Empty    ${order_ids}
    Length Should Be    ${order_ids}    3
    
    Set Global Variable  ${TEST_ORDER_IDS}     ${order_ids}
    Set Global Variable  ${TEST_ORDER_CODES}   ${order_codes}
    Set Global Variable  ${TEST_ORDER_DATA}    ${order_data_list}
    
    Log                 Successfully created bulk orders: ${TEST_ORDER_CODES}

03 - Get Bulk Orders Test
    [Documentation]     Test retrieving all bulk orders
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Test Bulk Orders
    
    FOR    ${index}    IN RANGE    ${TEST_ORDER_IDS.__len__()}
        ${order}=       Get Order By ID    ${TEST_ORDER_IDS}[${index}]
        Assert Order Details    ${order}    ${TEST_ORDER_DATA}[${index}]
        Log             Successfully retrieved order: ${order}[code]
    END

04 - Check Inventory Availability for Batch Test
    [Documentation]     Test checking inventory for all bulk orders
    [Tags]              inventory    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Test Bulk Orders
    
    ${availability}=    Check Inventory Availability For Batch    ${WAREHOUSE_ID}    ${TEST_ORDER_DATA}
    Should Not Be Empty    ${availability}
    
    Log                 Successfully checked inventory availability for bulk orders

05 - Update Orders to Picking in Batch Test
    [Documentation]     Test updating all bulk orders to PICKING
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Test Bulk Orders
    
    FOR    ${index}    IN RANGE    ${TEST_ORDER_IDS.__len__()}
        ${update_data}=  Create Dictionary
        ...              id=${TEST_ORDER_IDS}[${index}]
        ...              boothCode=${TEST_ORDER_DATA}[${index}][boothCode]
        ...              deliveryAdress=${TEST_ORDER_DATA}[${index}][deliveryAdress]
        ...              deliveryTime=${TEST_ORDER_DATA}[${index}][deliveryTime]
        ...              driverName=${TEST_ORDER_DATA}[${index}][driverName]
        ...              status=PICKING
        ...              updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 2}}, ${{"id": 2, "pickingQuantity": 3}} ]}
        
        ${updated_order}=  Update Order    ${TEST_ORDER_IDS}[${index}]    ${update_data}
        Should Be Equal    ${updated_order}[status]    PICKING
        Log                Successfully updated order ${TEST_ORDER_CODES}[${index}] to PICKING
    END

06 - Create Packages for Batch Test
    [Documentation]     Test creating packages for all bulk orders
    [Tags]              package    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Test Bulk Orders
    
    ${package_ids}=     Create List
    FOR    ${order_id}    IN    @{TEST_ORDER_IDS}
        ${package_id}   ${response}=    Create Package    ${order_id}
        Should Not Be Empty    ${package_id}
        Append To List  ${package_ids}    ${package_id}
        Log             Successfully created package: ${package_id} for order: ${order_id}
    END
    
    Set Global Variable  ${TEST_PACKAGE_IDS}    ${package_ids}

07 - Update Orders to Packaged in Batch Test
    [Documentation]     Test updating all bulk orders to PACKAGED
    [Tags]              update    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Test Bulk Orders
    
    FOR    ${index}    IN RANGE    ${TEST_ORDER_IDS.__len__()}
        ${update_data}=  Create Dictionary
        ...              id=${TEST_ORDER_IDS}[${index}]
        ...              boothCode=${TEST_ORDER_DATA}[${index}][boothCode]
        ...              deliveryAdress=${TEST_ORDER_DATA}[${index}][deliveryAdress]
        ...              deliveryTime=${TEST_ORDER_DATA}[${index}][deliveryTime]
        ...              driverName=${TEST_ORDER_DATA}[${index}][driverName]
        ...              status=PACKAGED
        ...              updateProductOrder=${[ ${{"id": 1, "pickingQuantity": 2}}, ${{"id": 2, "pickingQuantity": 3}} ]}
        
        ${updated_order}=  Update Order    ${TEST_ORDER_IDS}[${index}]    ${update_data}
        Should Be Equal    ${updated_order}[status]    PACKAGED
        Log                Successfully updated order ${TEST_ORDER_CODES}[${index}] to PACKAGED
    END

08 - Confirm Batch Delivery Test
    [Documentation]     Test confirming all bulk orders as delivered
    [Tags]              confirm    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Test Bulk Orders
    
    FOR    ${order_id}    IN    @{TEST_ORDER_IDS}
        ${result}=      Confirm Order    ${order_id}
        Should Be True  ${result}
        
        ${order}=       Get Order By ID    ${order_id}
        Should Be Equal  ${order}[status]    DELIVERED
        Log             Successfully confirmed order ${order_id} as DELIVERED
    END

09 - Verify Final Batch Orders and Packages Test
    [Documentation]     Test retrieving all bulk orders and packages after delivery
    [Tags]              retrieve    positive
    
    Run Keyword If      "${TEST_ORDER_IDS.__len__()}" == "0"    Create Test Bulk Orders
    Run Keyword If      "${TEST_PACKAGE_IDS.__len__()}" == "0"    Create Packages for Batch Test
    
    FOR    ${index}    IN RANGE    ${TEST_ORDER_IDS.__len__()}
        ${order}=       Get Order By ID    ${TEST_ORDER_IDS}[${index}]
        ${package}=     Get Package By ID    ${TEST_PACKAGE_IDS}[${index}]
        
        Should Be Equal  ${order}[status]    DELIVERED
        Should Not Be Empty    ${package}[orderId]
        Log             Successfully verified order ${TEST_ORDER_CODES}[${index}] and package ${TEST_PACKAGE_IDS}[${index}]
    END

10 - Cleanup Test Environment
    [Documentation]     Clean up test orders and packages
    [Tags]              cleanup
    
    FOR    ${package_id}    IN    @{TEST_PACKAGE_IDS}
        Delete Package    ${package_id}
    END
    
    FOR    ${order_id}    IN    @{TEST_ORDER_IDS}
        Delete Order    ${order_id}
    END
    
    Set Global Variable  ${TEST_ORDER_IDS}     @{EMPTY}
    Set Global Variable  ${TEST_PACKAGE_IDS}   @{EMPTY}
    Log                 Test environment cleaned up successfully