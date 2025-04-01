*** Settings ***
Documentation     Comprehensive End-to-End Test Suite for vKho API Operations
...               Covers Warehouse, Supplier, Product, and Order Operations
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_WAREHOUSE_ID}    ${EMPTY}
${TEST_SUPPLIER_ID}     ${EMPTY}
${TEST_PRODUCT_ID}      ${EMPTY}
${TEST_ORDER_ID}        ${EMPTY}
${TEST_WAREHOUSE_NAME}  ${EMPTY}
${TEST_SUPPLIER_NAME}   ${EMPTY}
${TEST_PRODUCT_NAME}    ${EMPTY}
${TEST_ORDER_CODE}      ${EMPTY}

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
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

Generate Unique Warehouse Data
    [Documentation]     Generate unique data for warehouse tests
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_name}=  Set Variable     Test Warehouse ${timestamp}
    ${warehouse_data}=  Create Dictionary
    ...                 name=${warehouse_name}
    ...                 address=123 Test Street
    ...                 acreage=1000
    [Return]            ${warehouse_data}

Generate Unique Supplier Data
    [Documentation]     Generate unique data for supplier tests
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_name}=   Set Variable     Test Supplier ${timestamp}
    ${supplier_data}=   Create Dictionary
    ...                 name=${supplier_name}
    ...                 email=supplier_${timestamp}@example.com
    ...                 phoneNumber=800567${timestamp}
    ...                 address=Test Address
    ...                 isActive=${TRUE}
    ...                 contractNumber=TST${timestamp}
    ...                 taxCode=57519${timestamp}
    ...                 cooperationDay=2023-03-20T00:00:00.000Z
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryIds=${EMPTY}  # Will be set later if needed
    [Return]            ${supplier_data}

Generate Unique Product Data
    [Documentation]     Generate unique data for product tests
    [Arguments]         ${warehouse_id}    ${supplier_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_name}=    Set Variable     Test Product ${timestamp}
    ${product_data}=    Create Dictionary
    ...                 name=${product_name}
    ...                 totalQuantity=100
    ...                 expectedQuantity=100
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
    [Return]            ${product_data}

Generate Unique Order Data
    [Documentation]     Generate unique data for order tests
    [Arguments]         ${warehouse_id}    ${product_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     ORD${timestamp}
    ${product_order}=   Create Dictionary
    ...                 total=10
    ...                 boothCode=BOOTH001
    ...                 sku=SKU${timestamp}
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
    [Return]            ${order_data}

Create Warehouse
    [Documentation]     Create a new warehouse and return its ID
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    ${warehouse_id}=    Convert To String    ${json}[id]
    [Return]            ${warehouse_id}    ${json}

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
    [Return]            ${supplier_id}    ${json}

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
    [Return]            ${product_id}    ${json}

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
    [Return]            ${order_id}    ${json}

Get Warehouse By ID
    [Documentation]     Retrieve a specific warehouse by ID
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    [Return]            ${json}

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
    [Return]            ${json}

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
    [Return]            ${json}

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
    [Return]            ${json}

Delete Warehouse
    [Documentation]     Delete a warehouse from the system
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    [Return]            ${TRUE}

Delete Supplier
    [Documentation]     Delete a supplier from the system
    [Arguments]         ${supplier_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /suppliers/delete/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    [Return]            ${TRUE}

Delete Product
    [Documentation]     Delete a product from the system
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    [Return]            ${TRUE}

Delete Order
    [Documentation]     Delete an order from the system
    [Arguments]         ${order_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /orders/delete/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    [Return]            ${TRUE}

Assert Entity Details
    [Documentation]     Verify entity details match expected values
    [Arguments]         ${entity}    ${expected_data}
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${entity}    Should Be Equal    ${entity}[${key}]    ${expected_data}[${key}]
        ...    msg=Entity ${key} value '${entity}[${key}]' does not match expected '${expected_data}[${key}]'
    END

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for end-to-end tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Warehouse Test
    [Documentation]     Test creating a new warehouse
    [Tags]              create    positive
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    Should Not Be Empty    ${warehouse_id}
    Should Be Equal     ${response}[name]    ${warehouse_data}[name]
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}  ${response}[name]
    Log                 Successfully created warehouse: ${TEST_WAREHOUSE_NAME} with ID: ${TEST_WAREHOUSE_ID}

03 - Create Supplier Test
    [Documentation]     Test creating a new supplier linked to the warehouse
    [Tags]              create    positive
    ${supplier_data}=   Generate Unique Supplier Data    ${TEST_WAREHOUSE_ID}
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    Should Not Be Empty    ${supplier_id}
    Should Be Equal     ${response}[name]    ${supplier_data}[name]
    Set Global Variable  ${TEST_SUPPLIER_ID}     ${supplier_id}
    Set Global Variable  ${TEST_SUPPLIER_NAME}   ${response}[name]
    Log                 Successfully created supplier: ${TEST_SUPPLIER_NAME} with ID: ${TEST_SUPPLIER_ID}

04 - Create Product Test
    [Documentation]     Test creating a new product linked to the warehouse and supplier
    [Tags]              create    positive
    ${product_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    ${product_id}    ${response}=    Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Should Be Equal     ${response}[name]    ${product_data}[name]
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Log                 Successfully created product: ${TEST_PRODUCT_NAME} with ID: ${TEST_PRODUCT_ID}

05 - Create Order Test
    [Documentation]     Test creating a new order linked to the warehouse and product
    [Tags]              create    positive
    ${order_data}=      Generate Unique Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_PRODUCT_ID}
    ${order_id}    ${response}=    Create Order    ${order_data}
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    Set Global Variable  ${TEST_ORDER_ID}        ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}      ${response}[code]
    Log                 Successfully created order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

06 - Retrieve Warehouse Test
    [Documentation]     Test retrieving the created warehouse
    [Tags]              retrieve    positive
    ${warehouse}=       Get Warehouse By ID    ${TEST_WAREHOUSE_ID}
    Assert Entity Details    ${warehouse}    ${warehouse_data}
    Log                 Successfully retrieved warehouse: ${warehouse}[name]

07 - Retrieve Supplier Test
    [Documentation]     Test retrieving the created supplier
    [Tags]              retrieve    positive
    ${supplier}=        Get Supplier By ID    ${TEST_SUPPLIER_ID}
    Assert Entity Details    ${supplier}    ${supplier_data}
    Log                 Successfully retrieved supplier: ${supplier}[name]

08 - Retrieve Product Test
    [Documentation]     Test retrieving the created product
    [Tags]              retrieve    positive
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    Assert Entity Details    ${product}    ${product_data}
    Log                 Successfully retrieved product: ${product}[name]

09 - Retrieve Order Test
    [Documentation]     Test retrieving the created order
    [Tags]              retrieve    positive
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Entity Details    ${order}    ${order_data}
    Log                 Successfully retrieved order: ${order}[code]

10 - Delete Order Test
    [Documentation]     Test deleting the created order
    [Tags]              delete    positive
    ${result}=          Delete Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    Log                 Successfully deleted order with ID: ${TEST_ORDER_ID}

11 - Delete Product Test
    [Documentation]     Test deleting the created product
    [Tags]              delete    positive
    ${result}=          Delete Product    ${TEST_PRODUCT_ID}
    Should Be True      ${result}
    Log                 Successfully deleted product with ID: ${TEST_PRODUCT_ID}

12 - Delete Supplier Test
    [Documentation]     Test deleting the created supplier
    [Tags]              delete    positive
    ${result}=          Delete Supplier    ${TEST_SUPPLIER_ID}
    Should Be True      ${result}
    Log                 Successfully deleted supplier with ID: ${TEST_SUPPLIER_ID}

13 - Delete Warehouse Test
    [Documentation]     Test deleting the created warehouse
    [Tags]              delete    positive
    ${result}=          Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Should Be True      ${result}
    Log                 Successfully deleted warehouse with ID: ${TEST_WAREHOUSE_ID}

14 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    Log                 Test environment cleaned up successfully