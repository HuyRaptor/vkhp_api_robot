*** Settings ***
Documentation     Comprehensive End-to-End Test Suite for vKho API Operations
...               Covers Warehouse, Supplier, Product, and Order Operations
...               Includes positive and negative tests with proper validation
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

Generate Unique Warehouse Data
    [Documentation]     Generate unique data for warehouse tests
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_name}=  Set Variable     Test Warehouse ${timestamp}
    ${warehouse_data}=  Create Dictionary
    ...                 name=${warehouse_name}
    ...                 address=123 Test Street
    ...                 acreage=1000
    RETURN            ${warehouse_data}

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
    ...                 productCategoryIds=${EMPTY}
    RETURN            ${supplier_data}

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
    RETURN            ${product_data}

Generate Unique Order Data
    [Documentation]     Generate unique data for order tests
    [Arguments]         ${warehouse_id}
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
    RETURN            ${order_data}

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
    RETURN            ${warehouse_id}    ${json}

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
    RETURN            ${supplier_id}    ${json}

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
    RETURN            ${product_id}    ${json}

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
    RETURN            ${order_id}    ${json}

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
    RETURN            ${json}

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
    RETURN            ${json}

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
    RETURN            ${json}

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
    RETURN            ${json}

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
    RETURN            ${json}

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
    RETURN            ${json}

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
    RETURN            ${json}

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
    RETURN            ${json}

Delete Warehouse
    [Documentation]     Delete a warehouse from the system
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
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
    RETURN            ${TRUE}

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
    Set Global Variable  ${TEST_WAREHOUSE_DATA}  ${warehouse_data}
    Log                 Successfully created warehouse: ${TEST_WAREHOUSE_NAME} with ID: ${TEST_WAREHOUSE_ID}

03 - Create Warehouse Missing Required Field Test
    [Documentation]     Test creating a warehouse with missing required fields
    [Tags]              create    negative
    ${incomplete_data}=  Create Dictionary    name=Incomplete Warehouse
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${incomplete_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    Log                 Successfully verified that creating a warehouse with missing fields fails

04 - Create Supplier Test
    [Documentation]     Test creating a new supplier linked to the warehouse
    [Tags]              create    positive
    ${supplier_data}=   Generate Unique Supplier Data    ${TEST_WAREHOUSE_ID}
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    Should Not Be Empty    ${supplier_id}
    Should Be Equal     ${response}[name]    ${supplier_data}[name]
    Set Global Variable  ${TEST_SUPPLIER_ID}     ${supplier_id}
    Set Global Variable  ${TEST_SUPPLIER_NAME}   ${response}[name]
    Set Global Variable  ${TEST_SUPPLIER_DATA}   ${supplier_data}
    Log                 Successfully created supplier: ${TEST_SUPPLIER_NAME} with ID: ${TEST_SUPPLIER_ID}

05 - Create Supplier Missing Required Field Test
    [Documentation]     Test creating a supplier with missing required fields
    [Tags]              create    negative
    ${incomplete_data}=  Generate Unique Supplier Data    ${TEST_WAREHOUSE_ID}
    Remove From Dictionary    ${incomplete_data}    email
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${incomplete_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    Log                 Successfully verified that creating a supplier with missing fields fails

06 - Create Product Test
    [Documentation]     Test creating a new product linked to the warehouse and supplier
    [Tags]              create    positive
    ${product_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    ${product_id}    ${response}=    Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Should Be Equal     ${response}[name]    ${product_data}[name]
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}
    Log                 Successfully created product: ${TEST_PRODUCT_NAME} with ID: ${TEST_PRODUCT_ID}

07 - Create Product Missing Required Field Test
    [Documentation]     Test creating a product with missing required fields
    [Tags]              create    negative
    ${incomplete_data}=  Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    Remove From Dictionary    ${incomplete_data}    totalQuantity
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${incomplete_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    Log                 Successfully verified that creating a product with missing fields fails

08 - Create Order Test
    [Documentation]     Test creating a new order linked to the warehouse
    [Tags]              create    positive
    ${order_data}=      Generate Unique Order Data    ${TEST_WAREHOUSE_ID}
    ${order_id}    ${response}=    Create Order    ${order_data}
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    Set Global Variable  ${TEST_ORDER_ID}        ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}      ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}      ${order_data}
    Log                 Successfully created order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

09 - Create Order Missing Required Field Test
    [Documentation]     Test creating an order with missing required fields
    [Tags]              create    negative
    ${incomplete_data}=  Generate Unique Order Data    ${TEST_WAREHOUSE_ID}
    Remove From Dictionary    ${incomplete_data}    productOrders
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${incomplete_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    Log                 Successfully verified that creating an order with missing fields fails

10 - Update Warehouse Test
    [Documentation]     Test updating an existing warehouse
    [Tags]              update    positive
    ${updated_name}=    Set Variable    ${TEST_WAREHOUSE_NAME} Updated
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_WAREHOUSE_ID}
    ...                 name=${updated_name}
    ...                 code=WHS${TEST_WAREHOUSE_ID}
    ...                 acreage=1500
    ...                 address=789 Updated Street
    ...                 createDate=2025-03-31T00:00:00.000Z
    ...                 status=ENABLE
    ${updated_warehouse}=    Update Warehouse    ${TEST_WAREHOUSE_ID}    ${update_data}
    Should Be Equal     ${updated_warehouse}[name]    ${updated_name}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}    ${updated_name}
    Set Global Variable  ${TEST_WAREHOUSE_DATA}    ${update_data}
    Log                 Successfully updated warehouse: ${updated_warehouse}[name]

11 - Update Supplier Test
    [Documentation]     Test updating an existing supplier
    [Tags]              update    positive
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
    Log                 Successfully updated supplier: ${updated_supplier}[name]

12 - Update Product Test
    [Documentation]     Test updating an existing product
    [Tags]              update    positive
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
    ...                 orderId=${EMPTY}
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
    Log                 Successfully updated product: ${updated_product}[name]

13 - Update Order Test
    [Documentation]     Test updating an existing order
    [Tags]              update    positive
    ${updated_driver}=  Set Variable    Jane Doe
    ${update_product_order}=  Create Dictionary    id=1    pickingQuantity=5
    ${update_product_orders}=  Create List      ${update_product_order}
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_ORDER_ID}
    ...                 boothCode=BOOTH002
    ...                 deliveryAdress=789 Updated Delivery Street
    ...                 deliveryTime=2025-04-02T12:00:00.000Z
    ...                 driverName=${updated_driver}
    ...                 status=PICKING
    ...                 updateProductOrder=${update_product_orders}
    ${updated_order}=   Update Order    ${TEST_ORDER_ID}    ${update_data}
    Should Be Equal     ${updated_order}[driverName]    ${updated_driver}
    Set Global Variable  ${TEST_ORDER_DATA}    ${update_data}
    Log                 Successfully updated order: ${updated_order}[code]

14 - Retrieve Warehouse Test
    [Documentation]     Test retrieving the updated warehouse
    [Tags]              retrieve    positive
    ${warehouse}=       Get Warehouse By ID    ${TEST_WAREHOUSE_ID}
    Assert Entity Details    ${warehouse}    ${TEST_WAREHOUSE_DATA}
    Log                 Successfully retrieved warehouse: ${warehouse}[name]

15 - Retrieve Supplier Test
    [Documentation]     Test retrieving the updated supplier
    [Tags]              retrieve    positive
    ${supplier}=        Get Supplier By ID    ${TEST_SUPPLIER_ID}
    Assert Entity Details    ${supplier}    ${TEST_SUPPLIER_DATA}
    Log                 Successfully retrieved supplier: ${supplier}[name]

16 - Retrieve Product Test
    [Documentation]     Test retrieving the updated product
    [Tags]              retrieve    positive
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    Assert Entity Details    ${product}    ${TEST_PRODUCT_DATA}
    Log                 Successfully retrieved product: ${product}[name]

17 - Retrieve Order Test
    [Documentation]     Test retrieving the updated order
    [Tags]              retrieve    positive
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Entity Details    ${order}    ${TEST_ORDER_DATA}
    Log                 Successfully retrieved order: ${order}[code]

18 - Delete Order Test
    [Documentation]     Test deleting the updated order
    [Tags]              delete    positive
    ${result}=          Delete Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    Log                 Successfully deleted order with ID: ${TEST_ORDER_ID}

19 - Delete Product Test
    [Documentation]     Test deleting the updated product
    [Tags]              delete    positive
    ${result}=          Delete Product    ${TEST_PRODUCT_ID}
    Should Be True      ${result}
    Log                 Successfully deleted product with ID: ${TEST_PRODUCT_ID}

20 - Delete Supplier Test
    [Documentation]     Test deleting the updated supplier
    [Tags]              delete    positive
    ${result}=          Delete Supplier    ${TEST_SUPPLIER_ID}
    Should Be True      ${result}
    Log                 Successfully deleted supplier with ID: ${TEST_SUPPLIER_ID}

21 - Delete Warehouse Test
    [Documentation]     Test deleting the updated warehouse
    [Tags]              delete    positive
    ${result}=          Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Should Be True      ${result}
    Log                 Successfully deleted warehouse with ID: ${TEST_WAREHOUSE_ID}

22 - Delete Non-Existent Warehouse Test
    [Documentation]     Test deleting a warehouse that doesn't exist
    [Tags]              delete    negative
    ${non_existent_id}=  Set Variable    99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Log                 Successfully verified that deleting a non-existent warehouse fails

23 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    Log                 Test environment cleaned up successfully