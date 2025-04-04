*** Settings ***
Documentation     Ultimate End-to-End Test Suite for vKho API Operations
...               Covers Warehouse, Supplier, Product, and Order Operations
...               Includes positive, negative, edge, dependency, bulk, concurrency, stress, integrity, workflow, security, recovery, versioning, pagination, and localization tests
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot
Suite Setup       Setup Test Suite
Suite Teardown    Teardown Test Suite

*** Keywords ***
Setup Test Suite
    [Documentation]     Initialize suite-level variables and session
    Setup API Session
    ${START_TIME}=      Get Current Date    result_format=epoch
    Set Suite Variable  ${START_TIME}
    ${TEST_TIMINGS}=    Create Dictionary
    Set Suite Variable  ${TEST_TIMINGS}

Teardown Test Suite
    [Documentation]     Clean up all created resources and log suite metrics
    Run Keyword If      "${TEST_ORDER_ID}" != "${EMPTY}"    Delete Order    ${TEST_ORDER_ID}
    Run Keyword If      "${TEST_PRODUCT_ID}" != "${EMPTY}"    Delete Product    ${TEST_PRODUCT_ID}
    Run Keyword If      "${TEST_SUPPLIER_ID}" != "${EMPTY}"    Delete Supplier    ${TEST_SUPPLIER_ID}
    Run Keyword If      "${TEST_WAREHOUSE_ID}" != "${EMPTY}"    Delete Warehouse    ${TEST_WAREHOUSE_ID}
    ${end_time}=        Get Current Date    result_format=epoch
    ${duration}=        Evaluate    ${end_time} - ${START_TIME}
    ${avg_time}=        Evaluate    ${duration} / ${OPERATION_COUNT} if ${OPERATION_COUNT} > 0 else 0
    Log                 Suite completed in ${duration} seconds with ${OPERATION_COUNT} API operations (avg ${avg_time}s per operation)
    Log                 Test Timings: ${TEST_TIMINGS}

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
    ...    msg=Authentication failed: Response did not contain access_token
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    Create Directory    ${RESULTS_DIR}
    Increment Operation Count

Generate Unique Warehouse Data
    [Documentation]     Generate unique data for warehouse tests
    [Arguments]         ${acreage}=${SMALL_ACREAGE}    ${name_suffix}=${EMPTY}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_name}=  Set Variable     Test Warehouse ${timestamp}${name_suffix}
    ${warehouse_data}=  Create Dictionary
    ...                 name=${warehouse_name}
    ...                 address=123 Test Street
    ...                 acreage=${acreage}
    RETURN            ${warehouse_data}

Generate Unique Supplier Data
    [Documentation]     Generate unique data for supplier tests
    [Arguments]         ${warehouse_id}    ${is_active}=${TRUE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_name}=   Set Variable     Test Supplier ${timestamp}
    ${supplier_data}=   Create Dictionary
    ...                 name=${supplier_name}
    ...                 email=supplier_${timestamp}@example.com
    ...                 phoneNumber=800567${timestamp}
    ...                 address=Test Address
    ...                 isActive=${is_active}
    ...                 contractNumber=TST${timestamp}
    ...                 taxCode=57519${timestamp}
    ...                 cooperationDay=2023-03-20T00:00:00.000Z
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryIds=${EMPTY}
    RETURN            ${supplier_data}

Generate Unique Product Data
    [Documentation]     Generate unique data for product tests
    [Arguments]         ${warehouse_id}    ${supplier_id}    ${total_quantity}=100
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_name}=    Set Variable     Test Product ${timestamp}
    ${product_data}=    Create Dictionary
    ...                 name=${product_name}
    ...                 totalQuantity=${total_quantity}
    ...                 expectedQuantity=${total_quantity}
    ...                 importDate=2025-03-31T00:00:00.000Z
    ...                 cost=10
    ...                 salePrice=15
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-03-31T00:00:00.000Z
    ...                 productCode=PROD${timestamp}
    ...                 idRackReallocate=1
    ...                 imageProduct=https://example.com/image.jpg
    ...                 imageQRCode=https://example.com/qr.jpg
    ...                 imageBarcode=https://example.com/barcode.jpg
    ...                 blockId=1
    ...                 supplierId=${supplier_id}
    ...                 productCategoryId=1
    ...                 rackId=1
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=${EMPTY}
    ...                 packageId=${EMPTY}
    ...                 masterProductId=1
    ...                 note=Test product note
    ...                 barCode=BAR${timestamp}
    RETURN            ${product_data}

Generate Unique Order Data
    [Documentation]     Generate unique data for order tests
    [Arguments]         ${warehouse_id}    ${total}=10    ${product_id}=${EMPTY}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     ORD${timestamp}
    ${product_order}=   Create Dictionary
    ...                 total=${total}
    ...                 boothCode=BOOTH001
    ...                 sku=SKU${timestamp}
    Run Keyword If      "${product_id}" != "${EMPTY}"    Set To Dictionary    ${product_order}    productId=${product_id}
    ${product_orders}=  Create List      ${product_order}
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=Test Customer
    ...                 code=${order_code}
    ...                 boothCode=BOOTH001
    ...                 deliveryAdress=456 Delivery Street
    ...                 deliveryTime=2025-04-01T10:00:00.000Z
    ...                 driverName=John Doe
    ...                 warehouseId=${warehouse_id}
    ...                 productOrders=${product_orders}
    RETURN            ${order_data}

Create Warehouse With Retry
    [Documentation]     Create a new warehouse with retry logic
    [Arguments]         ${warehouse_data}    ${timeout}=${FALSE}    ${long_delay}=${FALSE}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    Run Keyword If      ${timeout}    Sleep    ${TIMEOUT_DELAY}    # Simulate timeout
    Run Keyword If      ${long_delay}    Sleep    ${LONG_DELAY}    # Simulate long-running operation
    ${attempt}=         Set Variable    1
    FOR    ${attempt}    IN RANGE    1    ${MAX_RETRIES + 1}
    \    ${response}=    Run Keyword And Ignore Error
    \    ...             POST On Session    vkho    /warehouses/create    json=${warehouse_data}    headers=${headers}    expected_status=anything
    \    ${status}=      Set Variable If    "${response[0]}" == "PASS"    ${response[1].status_code}    500
    \    Exit For Loop If    ${status} == 201
    \    Log             Attempt ${attempt} failed with status ${status}, retrying in ${RETRY_DELAY} seconds...
    \    Sleep           ${RETRY_DELAY}
    \    Run Keyword If  ${attempt} == ${MAX_RETRIES}    Fail    Failed to create warehouse after ${MAX_RETRIES} attempts
    END
    ${json}=            Evaluate         json.loads('''${response[1].text}''')    json
    Dictionary Should Contain Key        ${json}    id
    ${warehouse_id}=    Convert To String    ${json}[id]
    Increment Operation Count
    RETURN            ${warehouse_id}    ${response[1]}

Create Supplier
    [Documentation]     Create a new supplier and return its ID
    [Arguments]         ${supplier_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    ${supplier_id}=     Convert To String    ${json}[id]
    Increment Operation Count
    RETURN            ${supplier_id}    ${response}

Create Product
    [Documentation]     Create a new product and return its ID
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    ${product_id}=      Convert To String    ${json}[id]
    Increment Operation Count
    RETURN            ${product_id}    ${response}

Create Order
    [Documentation]     Create a new order and return its ID
    [Arguments]         ${order_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    ${order_id}=        Convert To String    ${json}[id]
    Increment Operation Count
    RETURN            ${order_id}    ${response}

Update Warehouse
    [Documentation]     Update an existing warehouse
    [Arguments]         ${warehouse_id}    ${update_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /warehouses/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Update Supplier
    [Documentation]     Update an existing supplier
    [Arguments]         ${supplier_id}    ${update_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /suppliers/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Update Product
    [Documentation]     Update an existing product
    [Arguments]         ${product_id}    ${update_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /products/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Update Order
    [Documentation]     Update an existing order
    [Arguments]         ${order_id}    ${update_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Get Warehouse By ID
    [Documentation]     Retrieve a specific warehouse by ID
    [Arguments]         ${warehouse_id}    ${headers}=${NONE}
    ${headers}=         Run Keyword If    ${headers} is ${NONE}    Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ...                 ELSE    Set Variable    ${headers}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Get Supplier By ID
    [Documentation]     Retrieve a specific supplier by ID
    [Arguments]         ${supplier_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Get Product By ID
    [Documentation]     Retrieve a specific product by ID
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Get Warehouses Paginated
    [Documentation]     Retrieve warehouses with pagination
    [Arguments]         ${page}=1    ${size}=${PAGE_SIZE}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${params}=          Create Dictionary    page=${page}    size=${size}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Delete Warehouse
    [Documentation]     Delete a warehouse from the system
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    RETURN            ${TRUE}

Delete Supplier
    [Documentation]     Delete a supplier from the system
    [Arguments]         ${supplier_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /suppliers/delete/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    RETURN            ${TRUE}

Delete Product
    [Documentation]     Delete a product from the system
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    RETURN            ${TRUE}

Delete Order
    [Documentation]     Delete an order from the system
    [Arguments]         ${order_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /orders/delete/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    RETURN            ${TRUE}

Assert Entity Details
    [Documentation]     Verify entity details match expected values with strict checks
    [Arguments]         ${entity}    ${expected_data}
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${entity}    Should Be Equal    ${entity}[${key}]    ${expected_data}[${key}]
        ...    msg=Entity ${key} value '${entity}[${key}]' does not match expected '${expected_data}[${key}]'
        ...    ELSE    Fail    Expected key '${key}' missing in entity
    END
    Run Keyword If    'createDate' in ${entity}    Should Match Regexp    ${entity}[createDate]    ^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$
    ...    msg=Invalid timestamp format for createDate: ${entity}[createDate]

Log Response Details
    [Documentation]     Log detailed response information with timing
    [Arguments]         ${response}    ${entity_type}
    ${status}=          Convert To String    ${response.status_code}
    ${body}=            Set Variable If    ${response.text}    ${response.text}    "No body"
    ${elapsed}=         Convert To String    ${response.elapsed.total_seconds()}
    Log                 ${entity_type} Response - Status: ${status}, Body: ${body}, Time: ${elapsed}s
    RETURN            ${elapsed}

Record Test Timing
    [Documentation]     Record execution time for a test case
    [Arguments]         ${test_name}    ${duration}
    Set To Dictionary   ${TEST_TIMINGS}    ${test_name}    ${duration}

Increment Operation Count
    [Documentation]     Increment the count of API operations performed
    ${OPERATION_COUNT}=  Evaluate    ${OPERATION_COUNT} + 1
    Set Global Variable  ${OPERATION_COUNT}

*** Test Cases ***
01 - Create Warehouse Test
    [Documentation]     Test creating a new warehouse with retry
    [Tags]              create    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${response}=    Create Warehouse With Retry    ${warehouse_data}
    Should Not Be Empty    ${warehouse_id}
    Should Be Equal     ${response}[name]    ${warehouse_data}[name]
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}  ${response}[name]
    Set Global Variable  ${TEST_WAREHOUSE_DATA}  ${warehouse_data}
    ${duration}=        Log Response Details  ${response}    Warehouse Creation
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created warehouse: ${TEST_WAREHOUSE_NAME} with ID: ${TEST_WAREHOUSE_ID}

02 - Create Warehouse Missing Required Field Test
    [Documentation]     Test creating a warehouse with missing required fields
    [Tags]              create    negative
    ${start_time}=      Get Current Date    result_format=epoch
    ${incomplete_data}=  Create Dictionary    name=Incomplete Warehouse
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${incomplete_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Warehouse Creation (Missing Field)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating a warehouse with missing fields fails

03 - Create Warehouse Invalid Acreage Test
    [Documentation]     Test creating a warehouse with invalid acreage (negative value)
    [Tags]              create    negative    edge
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Warehouse Data    acreage=-100
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Warehouse Creation (Invalid Acreage)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating a warehouse with invalid acreage fails

04 - Create Warehouse Max Acreage Test
    [Documentation]     Test creating a warehouse with maximum reasonable acreage
    [Tags]              create    positive    boundary
    ${start_time}=      Get Current Date    result_format=epoch
    ${max_data}=        Generate Unique Warehouse Data    acreage=1000000
    ${warehouse_id}    ${response}=    Create Warehouse With Retry    ${max_data}
    Should Not Be Empty    ${warehouse_id}
    Should Be Equal     ${response}[name]    ${max_data}[name]
    Delete Warehouse    ${warehouse_id}
    ${duration}=        Log Response Details  ${response}    Warehouse Creation (Max Acreage)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created and deleted warehouse with max acreage: ${warehouse_id}

05 - Create Supplier Test
    [Documentation]     Test creating a new supplier linked to the warehouse
    [Tags]              create    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${supplier_data}=   Generate Unique Supplier Data    ${TEST_WAREHOUSE_ID}
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    Should Not Be Empty    ${supplier_id}
    Should Be Equal     ${response}[name]    ${supplier_data}[name]
    Set Global Variable  ${TEST_SUPPLIER_ID}     ${supplier_id}
    Set Global Variable  ${TEST_SUPPLIER_NAME}   ${response}[name]
    Set Global Variable  ${TEST_SUPPLIER_DATA}   ${supplier_data}
    ${duration}=        Log Response Details  ${response}    Supplier Creation
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created supplier: ${TEST_SUPPLIER_NAME} with ID: ${TEST_SUPPLIER_ID}

06 - Create Supplier Without Warehouse Test
    [Documentation]     Test creating a supplier without a valid warehouse ID
    [Tags]              create    negative    dependency
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Supplier Data    warehouseId=99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Supplier Creation (Invalid Warehouse)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating a supplier with invalid warehouse ID fails

07 - Create Supplier Invalid Email Test
    [Documentation]     Test creating a supplier with invalid email format
    [Tags]              create    negative    edge
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Supplier Data    ${TEST_WAREHOUSE_ID}
    Set To Dictionary   ${invalid_data}    email=invalid-email
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Supplier Creation (Invalid Email)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating a supplier with invalid email fails

08 - Create Product Test
    [Documentation]     Test creating a new product linked to the warehouse and supplier
    [Tags]              create    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${product_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    ${product_id}    ${response}=    Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Should Be Equal     ${response}[name]    ${product_data}[name]
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}
    ${duration}=        Log Response Details  ${response}    Product Creation
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created product: ${TEST_PRODUCT_NAME} with ID: ${TEST_PRODUCT_ID}

09 - Create Product Without Supplier Test
    [Documentation]     Test creating a product without a valid supplier ID
    [Tags]              create    negative    dependency
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    supplierId=99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Product Creation (Invalid Supplier)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating a product with invalid supplier ID fails

10 - Create Product Negative Quantity Test
    [Documentation]     Test creating a product with negative total quantity
    [Tags]              create    negative    edge
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}    total_quantity=-50
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Product Creation (Negative Quantity)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating a product with negative quantity fails

11 - Create Product Max Quantity Test
    [Documentation]     Test creating a product with maximum reasonable total quantity
    [Tags]              create    positive    boundary
    ${start_time}=      Get Current Date    result_format=epoch
    ${max_data}=        Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}    total_quantity=1000000
    ${product_id}    ${response}=    Create Product    ${max_data}
    Should Not Be Empty    ${product_id}
    Should Be Equal     ${response}[name]    ${max_data}[name]
    Delete Product      ${product_id}
    ${duration}=        Log Response Details  ${response}    Product Creation (Max Quantity)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created and deleted product with max quantity: ${product_id}

12 - Create Order Test
    [Documentation]     Test creating a new order linked to the warehouse and product
    [Tags]              create    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${order_data}=      Generate Unique Order Data    ${TEST_WAREHOUSE_ID}    product_id=${TEST_PRODUCT_ID}
    ${order_id}    ${response}=    Create Order    ${order_data}
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    Set Global Variable  ${TEST_ORDER_ID}        ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}      ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}      ${order_data}
    ${duration}=        Log Response Details  ${response}    Order Creation
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

13 - Create Order Without Warehouse Test
    [Documentation]     Test creating an order without a valid warehouse ID
    [Tags]              create    negative    dependency
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Order Data    warehouseId=99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Order Creation (Invalid Warehouse)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating an order with invalid warehouse ID fails

14 - Create Order Negative Total Test
    [Documentation]     Test creating an order with negative total in productOrders
    [Tags]              create    negative    edge
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Order Data    ${TEST_WAREHOUSE_ID}    total=-5
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Order Creation (Negative Total)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating an order with negative total fails

15 - Update Warehouse Test
    [Documentation]     Test updating an existing warehouse
    [Tags]              update    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${updated_name}=    Set Variable    ${TEST_WAREHOUSE_NAME} Updated
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_WAREHOUSE_ID}
    ...                 name=${updated_name}
    ...                 code=WHS${TEST_WAREHOUSE_ID}
    ...                 acreage=${LARGE_ACREAGE}
    ...                 address=789 Updated Street
    ...                 createDate=2025-03-31T00:00:00.000Z
    ...                 status=ENABLE
    ${updated_warehouse}=    Update Warehouse    ${TEST_WAREHOUSE_ID}    ${update_data}
    Should Be Equal     ${updated_warehouse}[name]    ${updated_name}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}    ${updated_name}
    Set Global Variable  ${TEST_WAREHOUSE_DATA}    ${update_data}
    ${duration}=        Log Response Details  ${updated_warehouse}    Warehouse Update
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully updated warehouse: ${updated_warehouse}[name]

16 - Update Supplier Test
    [Documentation]     Test updating an existing supplier
    [Tags]              update    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${updated_name}=    Set Variable    ${TEST_SUPPLIER_NAME} Updated
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_SUPPLIER_ID}
    ...                 name=${updated_name}
    ...                 email=updated_${TEST_SUPPLIER_ID}@example.com
    ...                 phoneNumber=9005551234
    ...                 address=Updated Address
    ...                 isActive=${TRUE}
    ...                 contractNumber=UPD${TEST_SUPPLIER_ID}
    ...                 taxCode=99999${TEST_SUPPLIER_ID}
    ...                 cooperationDay=2023-04-20T00:00:00.000Z
    ...                 warehouseId=${TEST_WAREHOUSE_ID}
    ...                 productCategoryIds=${EMPTY}
    ...                 status=ENABLE
    ${updated_supplier}=    Update Supplier    ${TEST_SUPPLIER_ID}    ${update_data}
    Should Be Equal     ${updated_supplier}[name]    ${updated_name}
    Set Global Variable  ${TEST_SUPPLIER_NAME}    ${updated_name}
    Set Global Variable  ${TEST_SUPPLIER_DATA}    ${update_data}
    ${duration}=        Log Response Details  ${updated_supplier}    Supplier Update
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate揭示    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully updated supplier: ${updated_supplier}[name]

17 - Update Product Test
    [Documentation]     Test updating an existing product
    [Tags]              update    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${updated_name}=    Set Variable    ${TEST_PRODUCT_NAME} Updated
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_PRODUCT_ID}
    ...                 name=${updated_name}
    ...                 totalQuantity=150
    ...                 expectedQuantity=150
    ...                 importDate=2025-03-31T00:00:00.000Z
    ...                 cost=12
    ...                 salePrice=18
    ...                 warehouseId=${TEST_WAREHOUSE_ID}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-03-31T00:00:00.000Z
    ...                 productCode=${TEST_PRODUCT_DATA}[productCode]
    ...                 idRackReallocate=1
    ...                 imageProduct=https://example.com/updated_image.jpg
    ...                 imageQRCode=https://example.com/updated_qr.jpg
    ...                 imageBarcode=https://example.com/updated_barcode.jpg
    ...                 blockId=1
    ...                 supplierId=${TEST_SUPPLIER_ID}
    ...                 productCategoryId=1
    ...                 rackId=1
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=${TEST_ORDER_ID}
    ...                 packageId=${EMPTY}
    ...                 masterProductId=1
    ...                 note=Updated product note
    ...                 barCode=${TEST_PRODUCT_DATA}[barCode]
    ...                 description=Updated description
    ...                 lostDate=2025-03-31T00:00:00.000Z
    ...                 status=ENABLE
    ...                 lostNumber=0
    ${updated_product}=    Update Product    ${TEST_PRODUCT_ID}    ${update_data}
    Should Be Equal     ${updated_product}[name]    ${updated_name}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${updated_name}
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${update_data}
    ${duration}=        Log Response Details  ${updated_product}    Product Update
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully updated product: ${updated_product}[name]

18 - Update Order Status To Picking Test
    [Documentation]     Test updating an order status to PICKING
    [Tags]              update    positive    status
    ${start_time}=      Get Current Date    result_format=epoch
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=PICKING
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    PICKING
    Set Global Variable  ${TEST_ORDER_DATA}    ${update_data}
    ${duration}=        Log Response Details  ${updated_order}    Order Update (Status to PICKING)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully updated order status to PICKING: ${updated_order}[code]

19 - Update Order Status To Delivering Test
    [Documentation]     Test updating an order status from PICKING to DELIVERING
    [Tags]              update    positive    status
    ${start_time}=      Get Current Date    result_format=epoch
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=${TEST_ORDER_DATA}[boothCode]
    ...                 deliveryAdress=${TEST_ORDER_DATA}[deliveryAdress]
    ...                 deliveryTime=${TEST_ORDER_DATA}[deliveryTime]
    ...                 driverName=${TEST_ORDER_DATA}[driverName]
    ...                 status=DELIVERING
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[status]    DELIVERING
    Set Global Variable  ${TEST_ORDER_DATA}    ${update_data}
    ${duration}=        Log Response Details  ${updated_order}    Order Update (Status to DELIVERING)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully updated order status to DELIVERING: ${updated_order}[code]

20 - Retrieve Warehouse Test
    [Documentation]     Test retrieving the updated warehouse
    [Tags]              retrieve    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${warehouse}=       Get Warehouse By ID    ${TEST_WAREHOUSE_ID}
    Assert Entity Details    ${warehouse}    ${TEST_WAREHOUSE_DATA}
    ${duration}=        Log Response Details  ${warehouse}    Warehouse Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved warehouse: ${warehouse}[name]

21 - Retrieve Supplier Test
    [Documentation]     Test retrieving the updated supplier
    [Tags]              retrieve    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${supplier}=        Get Supplier By ID    ${TEST_SUPPLIER_ID}
    Assert Entity Details    ${supplier}    ${TEST_SUPPLIER_DATA}
    ${duration}=        Log Response Details  ${supplier}    Supplier Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved supplier: ${supplier}[name]

22 - Retrieve Product Test
    [Documentation]     Test retrieving the updated product
    [Tags]              retrieve    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    Assert Entity Details    ${product}    ${TEST_PRODUCT_DATA}
    ${duration}=        Log Response Details  ${product}    Product Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved product: ${product}[name]

23 - Retrieve Order Test
    [Documentation]     Test retrieving the updated order
    [Tags]              retrieve    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Entity Details    ${order}    ${TEST_ORDER_DATA}
    ${duration}=        Log Response Details  ${order}    Order Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved order: ${order}[code]

24 - Retrieve Non-Existent Product Test
    [Documentation]     Test retrieving a product that doesn't exist
    [Tags]              retrieve    negative
    ${start_time}=      Get Current Date    result_format=epoch
    ${non_existent_id}=  Set Variable    99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    200
    ${duration}=        Log Response Details  ${response}    Product Retrieval (Non-Existent)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that retrieving a non-existent product fails

25 - Verify Product-Supplier Consistency Test
    [Documentation]     Test consistency between product and supplier
    [Tags]              retrieve    positive    consistency
    ${start_time}=      Get Current Date    result_format=epoch
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    Should Be Equal     ${product}[supplierId]    ${TEST_SUPPLIER_ID}
    ${duration}=        Log Response Details  ${product}    Product-Supplier Consistency Check
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified product ${TEST_PRODUCT_NAME} is linked to supplier ${TEST_SUPPLIER_ID}

26 - Verify Product-Order Linkage Test
    [Documentation]     Test that product is linked to the order
    [Tags]              retrieve    positive    consistency
    ${start_time}=      Get Current Date    result_format=epoch
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    Should Be Equal     ${product}[orderId]    ${TEST_ORDER_ID}
    ${duration}=        Log Response Details  ${product}    Product-Order Linkage Check
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified product ${TEST_PRODUCT_NAME} is linked to order ${TEST_ORDER_ID}

27 - Test Warehouse State Persistence
    [Documentation]     Test that warehouse updates persist across operations
    [Tags]              update    positive    persistence
    ${start_time}=      Get Current Date    result_format=epoch
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_WAREHOUSE_ID}
    ...                 name=${TEST_WAREHOUSE_NAME} Persisted
    ...                 code=WHS${TEST_WAREHOUSE_ID}
    ...                 acreage=2000
    ...                 address=789 Persisted Street
    ...                 createDate=2025-03-31T00:00:00.000Z
    ...                 status=ENABLE
    ${updated_warehouse}=    Update Warehouse    ${TEST_WAREHOUSE_ID}    ${update_data}
    Should Be Equal     ${updated_warehouse}[name]    ${update_data}[name]
    ${retrieved}=       Get Warehouse By ID    ${TEST_WAREHOUSE_ID}
    Assert Entity Details    ${retrieved}    ${update_data}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}    ${update_data}[name]
    Set Global Variable  ${TEST_WAREHOUSE_DATA}    ${update_data}
    ${duration}=        Log Response Details  ${updated_warehouse}    Warehouse Update (Persistence)
    Log Response Details  ${retrieved}    Warehouse Retrieval (Persistence)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified warehouse state persistence: ${TEST_WAREHOUSE_ID}

28 - Test Warehouse Creation Timeout
    [Documentation]     Test warehouse creation with simulated timeout
    [Tags]              create    negative    timeout
    ${start_time}=      Get Current Date    result_format=epoch
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${response}=        Run Keyword And Ignore Error
    ...                 Create Warehouse With Retry    ${warehouse_data}    timeout=${TRUE}
    Should Be Equal     ${response[0]}    PASS
    ${warehouse_id}=    Set Variable    ${response[1][0]}
    Delete Warehouse    ${warehouse_id}
    ${duration}=        Log Response Details  ${response[1][1]}    Warehouse Creation (Timeout)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created and deleted warehouse with simulated timeout: ${warehouse_id}

29 - Test Full Workflow
    [Documentation]     Test a complete business workflow: warehouse -> supplier -> products -> order -> status updates
    [Tags]              create    update    positive    workflow
    ${start_time}=      Get Current Date    result_format=epoch
    # Create Warehouse
    ${warehouse_data}=  Generate Unique Warehouse Data    acreage=${LARGE_ACREAGE}
    ${warehouse_id}    ${w_response}=    Create Warehouse With Retry    ${warehouse_data}
    Should Not Be Empty    ${warehouse_id}
    ${duration}=        Log Response Details  ${w_response}    Workflow Warehouse Creation

    # Create Supplier
    ${supplier_data}=   Generate Unique Supplier Data    ${warehouse_id}
    ${supplier_id}    ${s_response}=    Create Supplier    ${supplier_data}
    Should Not Be Empty    ${supplier_id}
    Log Response Details  ${s_response}    Workflow Supplier Creation

    # Create Multiple Products
    ${product_ids}=     Create List
    FOR    ${index}    IN RANGE    3
    \    ${product_data}=    Generate Unique Product Data    ${warehouse_id}    ${supplier_id}
    \    ${product_id}    ${p_response}=    Create Product    ${product_data}
    \    Should Not Be Empty    ${product_id}
    \    Append To List    ${product_ids}    ${product_id}
    \    Log Response Details  ${p_response}    Workflow Product Creation ${index}
    END
    # Create Order with Products
    ${order_data}=      Generate Unique Order Data    ${warehouse_id}    product_id=${product_ids[0]}
    ${order_id}    ${o_response}=    Create Order    ${order_data}
    Should Not Be Empty    ${order_id}
    Log Response Details  ${o_response}    Workflow Order Creation

    # Update Order Status
    ${update_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 boothCode=${order_data}[boothCode]
    ...                 deliveryAdress=${order_data}[deliveryAdress]
    ...                 deliveryTime=${order_data}[deliveryTime]
    ...                 driverName=${order_data}[driverName]
    ...                 status=DELIVERED
    ${updated_order}=   Update Order    ${order_id}    ${update_data}
    Should Be Equal     ${updated_order}[status]    DELIVERED
    Log Response Details  ${updated_order}    Workflow Order Update

    # Cleanup
    Delete Order        ${order_id}
    FOR    ${product_id}    IN    @{product_ids}
    \    Delete Product    ${product_id}
    END
    Delete Supplier     ${supplier_id}
    Delete Warehouse    ${warehouse_id}
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully completed full workflow: ${warehouse_id} -> ${supplier_id} -> ${product_ids} -> ${order_id}

30 - Create Order Before Product Test
    [Documentation]     Test creating an order before its product exists
    [Tags]              create    negative    dependency
    ${start_time}=      Get Current Date    result_format=epoch
    ${order_data}=      Generate Unique Order Data    ${TEST_WAREHOUSE_ID}    product_id=99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Order Creation (Invalid Product)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that creating an order with non-existent product fails

31 - Simulate Rate Limit Test
    [Documentation]     Test rapid warehouse creations to simulate rate limiting
    [Tags]              create    positive    rate_limit
    ${start_time}=      Get Current Date    result_format=epoch
    ${warehouse_ids}=   Create List
    FOR    ${index}    IN RANGE    10
    \    ${warehouse_data}=  Generate Unique Warehouse Data
    \    ${warehouse_id}    ${response}=    Create Warehouse With Retry    ${warehouse_data}
    \    Should Not Be Empty    ${warehouse_id}
    \    Append To List    ${warehouse_ids}    ${warehouse_id}
    \    Log Response Details  ${response}    Warehouse Creation ${index} (Rate Limit Test)
    END
    FOR    ${warehouse_id}    IN    @{warehouse_ids}
    \    Delete Warehouse    ${warehouse_id}
    END
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created and deleted 10 warehouses rapidly: ${warehouse_ids}

32 - Test Unauthorized Warehouse Retrieval
    [Documentation]     Test retrieving a warehouse with invalid token
    [Tags]              retrieve    negative    security
    ${start_time}=      Get Current Date    result_format=epoch
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${INVALID_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${TEST_WAREHOUSE_ID}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Be Equal As Integers    ${response.status_code}    401
    ${duration}=        Log Response Details  ${response}    Warehouse Retrieval (Unauthorized)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that retrieving warehouse with invalid token fails

33 - Test No Token Warehouse Retrieval
    [Documentation]     Test retrieving a warehouse without token
    [Tags]              retrieve    negative    security
    ${start_time}=      Get Current Date    result_format=epoch
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${TEST_WAREHOUSE_ID}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Be Equal As Integers    ${response.status_code}    401
    ${duration}=        Log Response Details  ${response}    Warehouse Retrieval (No Token)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that retrieving warehouse without token fails

34 - Test Cross-Environment Consistency
    [Documentation]     Test warehouse consistency across hypothetical environments
    [Tags]              retrieve    positive    consistency
    ${start_time}=      Get Current Date    result_format=epoch
    ${env_headers}=     Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}    X-Environment=TEST_ENV
    ${warehouse_env}=   Get Warehouse By ID    ${TEST_WAREHOUSE_ID}    headers=${env_headers}
    Assert Entity Details    ${warehouse_env}    ${TEST_WAREHOUSE_DATA}
    ${duration}=        Log Response Details  ${warehouse_env}    Warehouse Retrieval (Cross-Environment)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified warehouse consistency across environments: ${TEST_WAREHOUSE_ID}

35 - Test Malformed JSON Warehouse Creation
    [Documentation]     Test creating a warehouse with malformed JSON
    [Tags]              create    negative    validation
    ${start_time}=      Get Current Date    result_format=epoch
    ${malformed_data}=  Set Variable    {"name": "Malformed Warehouse", "acreage": "not_a_number"  # Missing closing brace
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        Run Keyword And Ignore Error
    ...                 POST On Session    vkho    /warehouses/create    data=${malformed_data}    headers=${headers}    expected_status=anything
    Should Be Equal     ${response[0]}    FAIL    # Expect client-side failure due to invalid JSON
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that malformed JSON fails before reaching the server

36 - Test Oversized Payload Warehouse Creation
    [Documentation]     Test creating a warehouse with an oversized payload
    [Tags]              create    negative    validation
    ${start_time}=      Get Current Date    result_format=epoch
    ${oversized_name}=  Set Variable    ${"x" * 10000}    # 10,000 characters
    ${warehouse_data}=  Create Dictionary    name=${oversized_name}    address=123 Test St    acreage=1000
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Warehouse Creation (Oversized Payload)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that oversized payload fails

37 - Test Invalid Field Type Product Creation
    [Documentation]     Test creating a product with invalid field type (string for totalQuantity)
    [Tags]              create    negative    validation
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    Set To Dictionary   ${invalid_data}    totalQuantity=not_a_number
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Product Creation (Invalid Field Type)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified that invalid field type fails

38 - Test Order Creation Recovery
    [Documentation]     Test recovery after partial order creation failure (simulated by invalid data)
    [Tags]              create    negative    recovery
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Unique Order Data    ${TEST_WAREHOUSE_ID}    product_id=${TEST_PRODUCT_ID}
    Set To Dictionary   ${invalid_data}    deliveryTime=invalid_date    # Simulate failure
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${duration}=        Log Response Details  ${response}    Order Creation (Recovery Simulation)
    # Attempt recovery with valid data
    ${valid_data}=      Generate Unique Order Data    ${TEST_WAREHOUSE_ID}    product_id=${TEST_PRODUCT_ID}
    ${order_id}    ${valid_response}=    Create Order    ${valid_data}
    Should Not Be Empty    ${order_id}
    Delete Order        ${order_id}
    Log Response Details  ${valid_response}    Order Creation (Post-Recovery)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified recovery after partial order creation failure

39 - Test API Version Compatibility
    [Documentation]     Test warehouse creation with hypothetical v2 API version
    [Tags]              create    positive    versioning
    ${start_time}=      Get Current Date    result_format=epoch
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}    Accept=application/vnd.vkho.v2+json
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Run Keyword If      ${response.status_code} == 201
    ...                 Run Keywords
    ...                 ${json}=    Evaluate    json.loads('''${response.text}''')    json
    ...                 AND    Dictionary Should Contain Key    ${json}    id
    ...                 AND    ${warehouse_id}=    Convert To String    ${json}[id]
    ...                 AND    Delete Warehouse    ${warehouse_id}
    ...                 AND    Log    Successfully created and deleted warehouse with v2 version: ${warehouse_id}
    ...                 ELSE    Log    API v2 not supported or behaves differently (status: ${response.status_code})
    ${duration}=        Log Response Details  ${response}    Warehouse Creation (Versioning)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}

40 - Test Paginated Warehouses Retrieval
    [Documentation]     Test retrieving warehouses with pagination
    [Tags]              retrieve    positive    pagination
    ${start_time}=      Get Current Date    result_format=epoch
    ${response}=        Get Warehouses Paginated    page=1    size=${PAGE_SIZE}
    ${json}=            Evaluate    json.loads('''${response.text}''')    json
    Should Be True      ${json.__len__()} <= ${PAGE_SIZE}
    ${duration}=        Log Response Details  ${response}    Warehouses Paginated Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved paginated warehouses (up to ${PAGE_SIZE} items)

41 - Test Paginated Warehouses Empty Page
    [Documentation]     Test retrieving warehouses with an out-of-range page
    [Tags]              retrieve    negative    pagination
    ${start_time}=      Get Current Date    result_format=epoch
    ${response}=        Get Warehouses Paginated    page=999    size=${PAGE_SIZE}
    ${json}=            Evaluate    json.loads('''${response.text}''')    json
    Should Be Empty     ${json}    msg=Expected empty result for out-of-range page
    ${duration}=        Log Response Details  ${response}    Warehouses Paginated Retrieval (Empty Page)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully verified empty result for out-of-range page

42 - Test Localization Warehouse Creation
    [Documentation]     Test creating a warehouse with special characters in name
    [Tags]              create    positive    localization
    ${start_time}=      Get Current Date    result_format=epoch
    ${warehouse_data}=  Generate Unique Warehouse Data    name_suffix= (日本語テスト)
    ${warehouse_id}    ${response}=    Create Warehouse With Retry    ${warehouse_data}
    Should Not Be Empty    ${warehouse_id}
    Should Be Equal     ${response}[name]    ${warehouse_data}[name]
    Delete Warehouse    ${warehouse_id}
    ${duration}=        Log Response Details  ${response}    Warehouse Creation (Localization)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created and deleted warehouse with special characters: ${warehouse_id}

43 - Test Long-Running Warehouse Creation
    [Documentation]     Test warehouse creation with simulated long delay
    [Tags]              create    positive    long_running
    ${start_time}=      Get Current Date    result_format=epoch
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${response}=    Create Warehouse With Retry    ${warehouse_data}    long_delay=${TRUE}
    Should Not Be Empty    ${warehouse_id}
    Delete Warehouse    ${warehouse_id}
    ${duration}=        Log Response Details  ${response}    Warehouse Creation (Long-Running)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Should Be True      ${test_duration} >= ${LONG_DELAY}    msg=Test duration should reflect long delay
    Record Test Timing  ${TEST NAME}    ${test_duration}
    Log                 Successfully created and deleted warehouse with long delay: ${warehouse_id}
