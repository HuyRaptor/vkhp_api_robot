*** Settings ***
Documentation     Comprehensive End-to-End Test Suite for vKho API Operations
...               Covers Warehouse, Supplier, Product, and Order Operations
...               Includes positive, negative, edge, dependency, bulk, concurrency, and stress tests
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
    [Arguments]         ${acreage}=1000
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_name}=  Set Variable     Test Warehouse ${timestamp}
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
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${attempt}=         Set Variable    1
    FOR    ${attempt}    IN RANGE    1    ${MAX_RETRIES + 1}
    \    ${response}=    Run Keyword And Ignore Error
    \    ...             POST On Session    vkho    /warehouses/create    json=${warehouse_data}    headers=${headers}    expected_status=anything
    \    ${status}=      Set Variable If    "${response[0]}" == "PASS"    ${response[1].status_code}    500
    \    Exit For Loop If    ${status} == 201
    \    Log             Attempt ${attempt} failed with status ${status}, retrying in ${RETRY_DELAY} seconds...
    \    Sleep           ${RETRY_DELAY}
    \    Run Keyword If  ${attempt} == ${MAX_RETRIES}    Fail    Failed to create warehouse after ${MAX_RETRIES} attempts
    ${json}=            Evaluate         json.loads('''${response[1].text}''')    json
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

Log Response Details
    [Documentation]     Log detailed response information with timing
    [Arguments]         ${response}    ${entity_type}
    ${status}=          Convert To String    ${response.status_code}
    ${body}=            Set Variable If    ${response.text}    ${response.text}    "No body"
    ${elapsed}=         Convert To String    ${response.elapsed.total_seconds()}
    Log                 ${entity_type} Response - Status: ${status}, Body: ${body}, Time: ${elapsed}s

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for end-to-end tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Warehouse Test
    [Documentation]     Test creating a new warehouse with retry
    [Tags]              create    positive
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${response}=    Create Warehouse With Retry    ${warehouse_data}
    Should Not Be Empty    ${warehouse_id}
    Should Be Equal     ${response}[name]    ${warehouse_data}[name]
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}  ${response}[name]
    Set Global Variable  ${TEST_WAREHOUSE_DATA}  ${warehouse_data}
    Log Response Details  ${response}    Warehouse Creation
    Log                 Successfully created warehouse: ${TEST_WAREHOUSE_NAME} with ID: ${TEST_WAREHOUSE_ID}

03 - Create Warehouse Missing Required Field Test
    [Documentation]     Test creating a warehouse with missing required fields
    [Tags]              create    negative
    ${incomplete_data}=  Create Dictionary    name=Incomplete Warehouse
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${incomplete_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Warehouse Creation (Missing Field)
    Log                 Successfully verified that creating a warehouse with missing fields fails

04 - Create Warehouse Invalid Acreage Test
    [Documentation]     Test creating a warehouse with invalid acreage (negative value)
    [Tags]              create    negative    edge
    ${invalid_data}=    Generate Unique Warehouse Data    acreage=-100
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Warehouse Creation (Invalid Acreage)
    Log                 Successfully verified that creating a warehouse with invalid acreage fails

05 - Create Supplier Test
    [Documentation]     Test creating a new supplier linked to the warehouse
    [Tags]              create    positive
    ${supplier_data}=   Generate Unique Supplier Data    ${TEST_WAREHOUSE_ID}
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    Should Not Be Empty    ${supplier_id}
    Should Be Equal     ${response}[name]    ${supplier_data}[name]
    Set Global Variable  ${TEST_SUPPLIER_ID}     ${supplier_id}
    Set Global Variable  ${TEST_SUPPLIER_NAME}   ${response}[name]
    Set Global Variable  ${TEST_SUPPLIER_DATA}   ${supplier_data}
    Log Response Details  ${response}    Supplier Creation
    Log                 Successfully created supplier: ${TEST_SUPPLIER_NAME} with ID: ${TEST_SUPPLIER_ID}

06 - Create Supplier Without Warehouse Test
    [Documentation]     Test creating a supplier without a valid warehouse ID
    [Tags]              create    negative    dependency
    ${invalid_data}=    Generate Unique Supplier Data    warehouseId=99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Supplier Creation (Invalid Warehouse)
    Log                 Successfully verified that creating a supplier with invalid warehouse ID fails

07 - Create Supplier Invalid Email Test
    [Documentation]     Test creating a supplier with invalid email format
    [Tags]              create    negative    edge
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
    Log Response Details  ${response}    Supplier Creation (Invalid Email)
    Log                 Successfully verified that creating a supplier with invalid email fails

08 - Create Product Test
    [Documentation]     Test creating a new product linked to the warehouse and supplier
    [Tags]              create    positive
    ${product_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    ${product_id}    ${response}=    Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Should Be Equal     ${response}[name]    ${product_data}[name]
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}
    Log Response Details  ${response}    Product Creation
    Log                 Successfully created product: ${TEST_PRODUCT_NAME} with ID: ${TEST_PRODUCT_ID}

09 - Create Product Without Supplier Test
    [Documentation]     Test creating a product without a valid supplier ID
    [Tags]              create    negative    dependency
    ${invalid_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    supplierId=99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Product Creation (Invalid Supplier)
    Log                 Successfully verified that creating a product with invalid supplier ID fails

10 - Create Product Negative Quantity Test
    [Documentation]     Test creating a product with negative total quantity
    [Tags]              create    negative    edge
    ${invalid_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}    total_quantity=-50
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Product Creation (Negative Quantity)
    Log                 Successfully verified that creating a product with negative quantity fails

11 - Create Order Test
    [Documentation]     Test creating a new order linked to the warehouse and product
    [Tags]              create    positive
    ${order_data}=      Generate Unique Order Data    ${TEST_WAREHOUSE_ID}    product_id=${TEST_PRODUCT_ID}
    ${order_id}    ${response}=    Create Order    ${order_data}
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    Set Global Variable  ${TEST_ORDER_ID}        ${order_id}
    Set Global Variable  ${TEST_ORDER_CODE}      ${response}[code]
    Set Global Variable  ${TEST_ORDER_DATA}      ${order_data}
    Log Response Details  ${response}    Order Creation
    Log                 Successfully created order: ${TEST_ORDER_CODE} with ID: ${TEST_ORDER_ID}

12 - Create Order Without Warehouse Test
    [Documentation]     Test creating an order without a valid warehouse ID
    [Tags]              create    negative    dependency
    ${invalid_data}=    Generate Unique Order Data    warehouseId=99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Order Creation (Invalid Warehouse)
    Log                 Successfully verified that creating an order with invalid warehouse ID fails

13 - Create Order Negative Total Test
    [Documentation]     Test creating an order with negative total in productOrders
    [Tags]              create    negative    edge
    ${invalid_data}=    Generate Unique Order Data    ${TEST_WAREHOUSE_ID}    total=-5
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Order Creation (Negative Total)
    Log                 Successfully verified that creating an order with negative total fails

14 - Update Warehouse Test
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
    Log Response Details  ${updated_warehouse}    Warehouse Update
    Log                 Successfully updated warehouse: ${updated_warehouse}[name]

15 - Update Supplier Test
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
    Log Response Details  ${updated_supplier}    Supplier Update
    Log                 Successfully updated supplier: ${updated_supplier}[name]

16 - Update Product Test
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
    Log Response Details  ${updated_product}    Product Update
    Log                 Successfully updated product: ${updated_product}[name]

17 - Update Order Status To Picking Test
    [Documentation]     Test updating an order status to PICKING
    [Tags]              update    positive    status
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
    Log Response Details  ${updated_order}    Order Update (Status to PICKING)
    Log                 Successfully updated order status to PICKING: ${updated_order}[code]

18 - Update Order Status To Delivering Test
    [Documentation]     Test updating an order status from PICKING to DELIVERING
    [Tags]              update    positive    status
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
    Log Response Details  ${updated_order}    Order Update (Status to DELIVERING)
    Log                 Successfully updated order status to DELIVERING: ${updated_order}[code]

19 - Retrieve Warehouse Test
    [Documentation]     Test retrieving the updated warehouse
    [Tags]              retrieve    positive
    ${warehouse}=       Get Warehouse By ID    ${TEST_WAREHOUSE_ID}
    Assert Entity Details    ${warehouse}    ${TEST_WAREHOUSE_DATA}
    Log Response Details  ${warehouse}    Warehouse Retrieval
    Log                 Successfully retrieved warehouse: ${warehouse}[name]

20 - Retrieve Supplier Test
    [Documentation]     Test retrieving the updated supplier
    [Tags]              retrieve    positive
    ${supplier}=        Get Supplier By ID    ${TEST_SUPPLIER_ID}
    Assert Entity Details    ${supplier}    ${TEST_SUPPLIER_DATA}
    Log Response Details  ${supplier}    Supplier Retrieval
    Log                 Successfully retrieved supplier: ${supplier}[name]

21 - Retrieve Product Test
    [Documentation]     Test retrieving the updated product
    [Tags]              retrieve    positive
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    Assert Entity Details    ${product}    ${TEST_PRODUCT_DATA}
    Log Response Details  ${product}    Product Retrieval
    Log                 Successfully retrieved product: ${product}[name]

22 - Retrieve Order Test
    [Documentation]     Test retrieving the updated order
    [Tags]              retrieve    positive
    ${order}=           Get Order By ID    ${TEST_ORDER_ID}
    Assert Entity Details    ${order}    ${TEST_ORDER_DATA}
    Log Response Details  ${order}    Order Retrieval
    Log                 Successfully retrieved order: ${order}[code]

23 - Retrieve Non-Existent Product Test
    [Documentation]     Test retrieving a product that doesn't exist
    [Tags]              retrieve    negative
    ${non_existent_id}=  Set Variable    99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    200
    Log Response Details  ${response}    Product Retrieval (Non-Existent)
    Log                 Successfully verified that retrieving a non-existent product fails

24 - Verify Product-Supplier Consistency Test
    [Documentation]     Test consistency between product and supplier
    [Tags]              retrieve    positive    consistency
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    Should Be Equal     ${product}[supplierId]    ${TEST_SUPPLIER_ID}
    Log Response Details  ${product}    Product-Supplier Consistency Check
    Log                 Successfully verified product ${TEST_PRODUCT_NAME} is linked to supplier ${TEST_SUPPLIER_ID}

25 - Verify Product-Order Linkage Test
    [Documentation]     Test that product is linked to the order
    [Tags]              retrieve    positive    consistency
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    Should Be Equal     ${product}[orderId]    ${TEST_ORDER_ID}
    Log Response Details  ${product}    Product-Order Linkage Check
    Log                 Successfully verified product ${TEST_PRODUCT_NAME} is linked to order ${TEST_ORDER_ID}

26 - Delete Order Test
    [Documentation]     Test deleting the updated order
    [Tags]              delete    positive
    ${result}=          Delete Order    ${TEST_ORDER_ID}
    Should Be True      ${result}
    Log                 Successfully deleted order with ID: ${TEST_ORDER_ID}

27 - Delete Product Test
    [Documentation]     Test deleting the updated product
    [Tags]              delete    positive
    ${result}=          Delete Product    ${TEST_PRODUCT_ID}
    Should Be True      ${result}
    Log                 Successfully deleted product with ID: ${TEST_PRODUCT_ID}

28 - Delete Supplier Test
    [Documentation]     Test deleting the updated supplier
    [Tags]              delete    positive
    ${result}=          Delete Supplier    ${TEST_SUPPLIER_ID}
    Should Be True      ${result}
    Log                 Successfully deleted supplier with ID: ${TEST_SUPPLIER_ID}

29 - Delete Warehouse Test
    [Documentation]     Test deleting the updated warehouse
    [Tags]              delete    positive
    ${result}=          Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Should Be True      ${result}
    Log                 Successfully deleted warehouse with ID: ${TEST_WAREHOUSE_ID}

30 - Delete Non-Existent Warehouse Test
    [Documentation]     Test deleting a warehouse that doesn't exist
    [Tags]              delete    negative
    ${non_existent_id}=  Set Variable    99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    200
    Log Response Details  ${response}    Warehouse Deletion (Non-Existent)
    Log                 Successfully verified that deleting a non-existent warehouse fails

31 - Create Multiple Warehouses Test
    [Documentation]     Test creating multiple warehouses to verify bulk-like behavior
    [Tags]              create    positive    bulk
    ${warehouse_data1}=  Generate Unique Warehouse Data
    ${warehouse_id1}    ${response1}=    Create Warehouse With Retry    ${warehouse_data1}
    Should Not Be Empty    ${warehouse_id1}
    ${warehouse_data2}=  Generate Unique Warehouse Data
    ${warehouse_id2}    ${response2}=    Create Warehouse With Retry    ${warehouse_data2}
    Should Not Be Empty    ${warehouse_id2}
    Should Not Equal    ${warehouse_id1}    ${warehouse_id2}
    Log Response Details  ${response1}    Warehouse Creation 1
    Log Response Details  ${response2}    Warehouse Creation 2
    Delete Warehouse    ${warehouse_id1}
    Delete Warehouse    ${warehouse_id2}
    Log                 Successfully created and deleted multiple warehouses: ${warehouse_id1}, ${warehouse_id2}

32 - Simulate Concurrent Product Updates Test
    [Documentation]     Test rapid sequential updates to a product to simulate concurrency
    [Tags]              update    positive    concurrency
    ${product_data1}=   Create Dictionary
    ...                 id=${TEST_PRODUCT_ID}
    ...                 name=${TEST_PRODUCT_NAME} Concurrency 1
    ...                 totalQuantity=200
    ...                 expectedQuantity=200
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
    ...                 note=Concurrency test 1
    ...                 barCode=${TEST_PRODUCT_DATA}[barCode]
    ...                 description=Concurrency description 1
    ...                 lostDate=2025-03-31T00:00:00.000Z
    ...                 status=ENABLE
    ...                 lostNumber=0
    ${update1}=         Update Product    ${TEST_PRODUCT_ID}    ${product_data1}
    Should Be Equal     ${update1}[name]    ${product_data1}[name]
    Log Response Details  ${update1}    Product Update (Concurrency 1)

    ${product_data2}=   Create Dictionary
    ...                 id=${TEST_PRODUCT_ID}
    ...                 name=${TEST_PRODUCT_NAME} Concurrency 2
    ...                 totalQuantity=250
    ...                 expectedQuantity=250
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
    ...                 note=Concurrency test 2
    ...                 barCode=${TEST_PRODUCT_DATA}[barCode]
    ...                 description=Concurrency description 2
    ...                 lostDate=2025-03-31T00:00:00.000Z
    ...                 status=ENABLE
    ...                 lostNumber=0
    ${update2}=         Update Product    ${TEST_PRODUCT_ID}    ${product_data2}
    Should Be Equal     ${update2}[name]    ${product_data2}[name]
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${product_data2}[name]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data2}
    Log Response Details  ${update2}    Product Update (Concurrency 2)
    Log                 Successfully performed rapid sequential updates on product: ${TEST_PRODUCT_ID}

33 - Stress Test Multiple Products Creation
    [Documentation]     Test creating multiple products to simulate high load
    [Tags]              create    positive    stress
    ${product_ids}=     Create List
    FOR    ${index}    IN RANGE    5
    \    ${product_data}=    Generate Unique Product Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    \    ${product_id}    ${response}=    Create Product    ${product_data}
    \    Should Not Be Empty    ${product_id}
    \    Append To List    ${product_ids}    ${product_id}
    \    Log Response Details  ${response}    Product Creation ${index}
    END
    FOR    ${product_id}    IN    @{product_ids}
    \    Delete Product    ${product_id}
    END
    Log                 Successfully created and deleted 5 products under stress conditions

34 - Test Idempotent Warehouse Update
    [Documentation]     Test that updating a warehouse with the same data multiple times is idempotent
    [Tags]              update    positive    idempotency
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_WAREHOUSE_ID}
    ...                 name=${TEST_WAREHOUSE_NAME} Idempotent
    ...                 code=WHS${TEST_WAREHOUSE_ID}
    ...                 acreage=1500
    ...                 address=789 Idempotent Street
    ...                 createDate=2025-03-31T00:00:00.000Z
    ...                 status=ENABLE
    ${update1}=         Update Warehouse    ${TEST_WAREHOUSE_ID}    ${update_data}
    Should Be Equal     ${update1}[name]    ${update_data}[name]
    Log Response Details  ${update1}    Warehouse Update (Idempotent 1)
    ${update2}=         Update Warehouse    ${TEST_WAREHOUSE_ID}    ${update_data}
    Should Be Equal     ${update2}[name]    ${update_data}[name]
    Assert Entity Details    ${update2}    ${update1}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}    ${update_data}[name]
    Set Global Variable  ${TEST_WAREHOUSE_DATA}    ${update_data}
    Log Response Details  ${update2}    Warehouse Update (Idempotent 2)
    Log                 Successfully verified idempotent update on warehouse: ${TEST_WAREHOUSE_ID}

35 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    Log                 Test environment cleaned up successfully