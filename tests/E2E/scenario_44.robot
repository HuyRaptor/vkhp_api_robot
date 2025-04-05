*** Settings ***
Documentation     Advanced Test Suite for Order Operations in vKho API
...               Includes complex scenarios like bulk operations, dependencies, concurrency, pagination, and edge cases
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
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
    [Documentation]     Generate unique data for order tests with nested product orders
    [Arguments]         ${custom_name}=Test Order    ${package_id}=${EMPTY}    ${supplier_id}=${EMPTY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     ORD${timestamp}
    
    # Generate nested product orders
    ${product_order_1}= Create Dictionary
    ...                 total=5
    ...                 boothCode=BTH${timestamp}-1
    ...                 sku=SKU${timestamp}-1
    ${product_order_2}= Create Dictionary
    ...                 total=3
    ...                 boothCode=BTH${timestamp}-2
    ...                 sku=SKU${timestamp}-2
    ${product_orders}=  Create List    ${product_order_1}    ${product_order_2}
    
    # Base order data
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=${custom_name} ${timestamp}
    ...                 code=${order_code}
    ...                 boothCode=BTH${timestamp}
    ...                 deliveryAdress=789 Order Street
    ...                 deliveryTime=2025-04-05T10:00:00.000Z
    ...                 driverName=John Doe ${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${product_orders}
    
    # Add optional dependencies
    Run Keyword If      "${package_id}" != "${EMPTY}"    Set To Dictionary    ${order_data}    packageId=${package_id}
    Run Keyword If      "${supplier_id}" != "${EMPTY}"   Set To Dictionary    ${order_data}    supplierId=${supplier_id}
    
    RETURN            ${order_data}

Create Order
    [Documentation]     Create a new order and return its ID
    [Arguments]         ${order_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${order_data}    nameCustomer
    ...    msg=Missing required parameter: nameCustomer
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${order_data}    productOrders
    ...    msg=Missing required parameter: productOrders
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create order request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create order response missing ID field
    
    # Return order ID and full response
    ${order_id}=        Convert To String    ${json}[id]
    RETURN            ${order_id}    ${json}

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get order request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get order response missing ID field
    
    RETURN            ${json}

Update Order
    [Documentation]     Update an existing order
    [Arguments]         ${order_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${order_id}
    ...    msg=Update data ID must match order_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    nameCustomer
    ...    msg=Update data missing required field: nameCustomer
    Dictionary Should Contain Key    ${update_data}    code
    ...    msg=Update data missing required field: code
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update order request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update order response missing ID field
    
    RETURN            ${json}

Delete Order
    [Documentation]     Delete an order from the system
    [Arguments]         ${order_id}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete order request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /orders/delete/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Orders
    [Documentation]     Retrieve all orders with filtering, pagination, and sorting
    [Arguments]         ${filter_params}=${EMPTY}    ${page}=${EMPTY}    ${limit}=${EMPTY}    ${sort}=${EMPTY}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    Run Keyword If      "${page}" != "${EMPTY}"             Set To Dictionary    ${params}    page=${page}
    Run Keyword If      "${limit}" != "${EMPTY}"            Set To Dictionary    ${params}    limit=${limit}
    Run Keyword If      "${sort}" != "${EMPTY}"             Set To Dictionary    ${params}    sort=${sort}
    
    # Send get all orders request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all orders response was empty
    
    RETURN            ${json}

Create Package
    [Documentation]     Create a package for order dependency
    ${timestamp}=       Evaluate         int(time.time())    time
    ${package_data}=    Create Dictionary
    ...                 packageCode=PKG${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=CREATED
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /packages/create
    ...                 json=${package_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${package_id}=      Convert To String    ${json}[id]
    RETURN            ${package_id}

Create Supplier
    [Documentation]     Create a supplier for order dependency
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_data}=   Create Dictionary
    ...                 name=Supplier ${timestamp}
    ...                 code=SUP${timestamp}
    ...                 phoneNumber=800555${timestamp}
    ...                 email=supplier_${timestamp}@example.com
    ...                 address=123 Supplier Street
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${supplier_id}=     Convert To String    ${json}[id]
    RETURN            ${supplier_id}

Bulk Create Orders
    [Documentation]     Create multiple orders in bulk with validation
    [Arguments]         ${count}=5
    
    ${order_ids}=       Create List
    FOR    ${i}    IN RANGE    ${count}
        ${order_data}=      Generate Unique Order Data    custom_name=Bulk Order ${i}
        ${order_id}    ${response}=    Create Order    ${order_data}
        Append To List      ${order_ids}    ${order_id}
    END
    RETURN            ${order_ids}

Assert Order Details
    [Documentation]     Verify order details match expected values
    [Arguments]         ${order}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${order} and "${key}" != "productOrders"
        ...               Should Be Equal    ${order}[${key}]    ${expected_data}[${key}]
        ...               msg=Order ${key} value '${order}[${key}]' does not match expected '${expected_data}[${key}]'
    END
    # Validate productOrders separately if present
    Run Keyword If    "productOrders" in ${expected_data}
    ...               Should Be Equal As Integers    ${order}[productOrders].__len__()    ${expected_data}[productOrders].__len__()
    ...               msg=Number of product orders does not match expected

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for complex order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Bulk Order Creation With Nested Products Test
    [Documentation]     Test creating multiple orders in bulk with nested product orders
    [Tags]              create    bulk    positive
    
    ${bulk_ids}=        Bulk Create Orders    count=5
    Should Not Be Empty    ${bulk_ids}
    ...    msg=Failed to create bulk orders: No IDs returned
    Should Be Equal As Integers    ${bulk_ids.__len__()}    5
    ...    msg=Expected 5 orders, but created ${bulk_ids.__len__()}
    
    # Verify each order exists and has product orders
    FOR    ${id}    IN    @{bulk_ids}
        ${order}=       Get Order By ID    ${id}
        Should Not Be Empty    ${order}
        ...    msg=Order ${id} from bulk creation not found
        Should Be True    ${order}[productOrders].__len__() >= 2
        ...    msg=Order ${id} does not contain expected product orders
    END
    
    Set Global Variable  ${BULK_ORDER_IDS}    ${bulk_ids}
    Log                 Successfully created and validated ${bulk_ids.__len__()} orders: ${bulk_ids}

03 - Create Order With Duplicate Code Test
    [Documentation]     Test creating an order with a duplicate code
    [Tags]              create    negative
    
    # Create first order
    ${order_data}=      Generate Unique Order Data    custom_name=Duplicate Order
    ${order_id}    ${response}=    Create Order    ${order_data}
    
    # Attempt to create second order with same code
    ${duplicate_data}=  Create Dictionary    &{order_data}
    Set To Dictionary   ${duplicate_data}    nameCustomer=Duplicate Order 2
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${duplicate_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of order with duplicate code
    Log                 Successfully verified duplicate code rejection: ${response.text}

04 - Order With Package And Supplier Dependency Test
    [Documentation]     Test creating and retrieving an order with package and supplier dependencies
    [Tags]              create    retrieve    dependency    positive
    
    # Create package and supplier
    ${package_id}=      Create Package
    ${supplier_id}=     Create Supplier
    Set Global Variable  ${TEST_PACKAGE_ID}    ${package_id}
    Set Global Variable  ${TEST_SUPPLIER_ID}   ${supplier_id}
    
    # Create order with dependencies
    ${order_data}=      Generate Unique Order Data    custom_name=Dependency Order    package_id=${package_id}    supplier_id=${supplier_id}
    ${order_id}    ${response}=    Create Order    ${order_data}
    
    # Retrieve and verify
    ${order}=           Get Order By ID    ${order_id}
    Assert Order Details    ${order}    ${order_data}
    Should Be Equal     ${order}[packageId]    ${package_id}
    ...    msg=Order packageId does not match expected
    Should Be Equal     ${order}[supplierId]    ${supplier_id}
    ...    msg=Order supplierId does not match expected
    
    Log                 Successfully created and retrieved order ${order_id} with package ${package_id} and supplier ${supplier_id}

05 - Concurrent Order Status Updates Test
    [Documentation]     Test concurrent status updates to an order with simulated race condition
    [Tags]              update    concurrent    positive
    
    # Create order
    ${order_data}=      Generate Unique Order Data    custom_name=Concurrent Order
    ${order_id}    ${response}=    Create Order    ${order_data}
    
    # First update: PICKING
    ${update_data_1}=   Create Dictionary
    ...                 id=${order_id}
    ...                 nameCustomer=${order_data}[nameCustomer]
    ...                 code=${order_data}[code]
    ...                 boothCode=${order_data}[boothCode]
    ...                 deliveryAdress=${order_data}[deliveryAdress]
    ...                 deliveryTime=${order_data}[deliveryTime]
    ...                 driverName=${order_data}[driverName]
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${order_data}[productOrders]
    ...                 status=PICKING
    ${updated_1}=       Update Order    ${order_id}    ${update_data_1}
    
    # Second update: DELIVERING (simulating race condition)
    ${update_data_2}=   Create Dictionary    &{update_data_1}
    Set To Dictionary   ${update_data_2}    status=DELIVERING
    ${updated_2}=       Update Order    ${order_id}    ${update_data_2}
    
    # Verify final state
    ${final_order}=     Get Order By ID    ${order_id}
    Should Be Equal     ${final_order}[status]    DELIVERING
    ...    msg=Second concurrent update did not apply correctly
    
    Log                 Successfully verified concurrent status updates on order ${order_id}

06 - Pagination Sorting And Filtering Orders Test
    [Documentation]     Test retrieving orders with pagination, sorting, and filtering
    [Tags]              retrieve    pagination    sort    filter    positive
    
    # Ensure bulk orders exist
    Run Keyword If      "${BULK_ORDER_IDS}" == "${EMPTY}"    Bulk Create Orders    count=10
    
    # Filter by code prefix, paginate (page 1, limit 4), sort by code descending
    ${filter_params}=   Create Dictionary    code=ORD
    ${orders_page_1}=   Get All Orders    filter_params=${filter_params}    page=1    limit=4    sort=code:desc
    
    # Verify response structure
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${orders_page_1}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${orders_page_1}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${orders_page_1}    records
    
    ${items}=           Set Variable    ${EMPTY}
    IF    ${has_data}
        ${items}=       Set Variable    ${orders_page_1}[data]
    ELSE IF    ${has_items}
        ${items}=       Set Variable    ${orders_page_1}[items]
    ELSE IF    ${has_records}
        ${items}=       Set Variable    ${orders_page_1}[records]
    END
    
    Should Not Be Empty    ${items}
    ...    msg=Paginated orders response was empty
    Should Be True         ${items.__len__()} <= 4
    ...    msg=Page 1 exceeded limit of 4 items: ${items.__len__()}
    
    # Verify sorting (descending order by code)
    ${prev_code}=       Set Variable    ${EMPTY}
    FOR    ${item}    IN    @{items}
        Run Keyword If    "${prev_code}" != "${EMPTY}"
        ...               Should Be True    "${item['code']}" <= "${prev_code}"
        ...               msg=Orders not sorted by code in descending order
        ${prev_code}=     Set Variable    ${item}[code]
    END
    
    Log                 Successfully retrieved paginated, sorted, and filtered orders: ${items.__len__()} items

07 - Delete Order With Package Dependency Test
    [Documentation]     Test deleting an order with a package dependency
    [Tags]              delete    dependency    negative
    
    # Create package and order
    ${package_id}=      Create Package
    ${order_data}=      Generate Unique Order Data    custom_name=Delete Dependency Order    package_id=${package_id}
    ${order_id}    ${response}=    Create Order    ${order_data}
    
    # Attempt to delete order with dependency
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /orders/delete/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Expect failure if API enforces dependency (assumption)
    Should Not Equal As Integers    ${response.status_code}    200
    ...    msg=API allowed deletion of order with dependent package
    Log                 Successfully verified rejection of order deletion with package ${package_id}

08 - Edge Case - Order With Malformed Delivery Time Test
    [Documentation]     Test creating an order with a malformed deliveryTime
    [Tags]              create    edge    negative
    
    ${order_data}=      Generate Unique Order Data    custom_name=Malformed Delivery Order
    Set To Dictionary   ${order_data}    deliveryTime=invalid-date-format
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of order with malformed deliveryTime
    Log                 Successfully verified rejection of order with malformed deliveryTime: ${response.text}

09 - Edge Case - Order With Maximum Length Fields Test
    [Documentation]     Test creating an order with maximum length field values
    [Tags]              create    edge    positive
    
    ${long_name}=       Set Variable    ${"A" * 255}    # Assuming 255 char limit
    ${long_code}=       Set Variable    ORD${"X" * 50}  # Assuming 50 char limit
    
    ${product_order}=   Create Dictionary    total=5    boothCode=BTH_MAX    sku=SKU_MAX
    ${product_orders}=  Create List    ${product_order}
    
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=${long_name}
    ...                 code=${long_code}
    ...                 boothCode=BTH_MAX
    ...                 deliveryAdress=789 Order Street
    ...                 deliveryTime=2025-04-05T10:00:00.000Z
    ...                 driverName=John Doe
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${product_orders}
    
    ${order_id}    ${response}=    Create Order    ${order_data}
    Should Not Be Empty    ${order_id}
    ...    msg=Failed to create order with max length fields
    
    ${order}=           Get Order By ID    ${order_id}
    Should Be Equal     ${order}[nameCustomer]    ${long_name}
    ...    msg=Created order nameCustomer does not match max length input
    Should Be Equal     ${order}[code]    ${long_code}
    ...    msg=Created order code does not match max length input
    Log                 Successfully created order with maximum length fields: ${order_id}

10 - Cleanup Test Environment
    [Documentation]     Clean up resources created during complex tests
    [Tags]              cleanup
    
    # Clean up bulk orders
    Run Keyword If      "${BULK_ORDER_IDS}" != "${EMPTY}"
    ...                 Run Keywords
    ...                 FOR    ${id}    IN    @{BULK_ORDER_IDS}
    ...                 Delete Order    ${id}
    ...                 END
    ...                 AND    Set Global Variable    ${BULK_ORDER_IDS}    ${EMPTY}
    
    # Clean up test order
    Run Keyword If      "${TEST_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Order    ${TEST_ORDER_ID}
    ...                 AND    Set Global Variable    ${TEST_ORDER_ID}    ${EMPTY}
    
    # Clean up package and supplier
    Run Keyword If      "${TEST_PACKAGE_ID}" != "${EMPTY}"
    ...                 DELETE On Session    vkho    /packages/delete/${TEST_PACKAGE_ID}    headers=${headers}
    ...                 AND    Set Global Variable    ${TEST_PACKAGE_ID}    ${EMPTY}
    Run Keyword If      "${TEST_SUPPLIER_ID}" != "${EMPTY}"
    ...                 DELETE On Session    vkho    /suppliers/delete/${TEST_SUPPLIER_ID}    headers=${headers}
    ...                 AND    Set Global Variable    ${TEST_SUPPLIER_ID}    ${EMPTY}
    
    Log                 Test environment cleaned up successfully
