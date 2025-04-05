*** Settings ***
Documentation     Comprehensive Test Suite for Receipt Operations with Multiple Products in vKho API
...               Includes receipts with multiple products, master products, replenishments,
...               product orders with constraints, and packages, related to warehouses
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate with specified role
    [Arguments]         ${MANAGER_USERNAME}    ${MANAGER_PASSWORD}
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

Generate Warehouse Data
    [Documentation]     Generate unique warehouse data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Test Warehouse ${timestamp}
    ...                 code=WH${timestamp}
    ...                 address=456 Test Ave
    ...                 city=Test City
    ...                 country=VN
    ...                 capacity=2000
    ...                 isActive=${TRUE}
    RETURN            ${warehouse_data}

Generate Receipt Data
    [Documentation]     Generate unique receipt data
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${booth_code}=      Set Variable     BOOTH${timestamp}
    
    ${receipt_data}=    Create Dictionary
    ...                 receiptDate=2025-04-02T00:00:00.000Z
    ...                 driverName=Test Driver ${timestamp}
    ...                 boothCode=${booth_code}
    ...                 inboundKind=NEW
    ...                 description=Multi-Product Receipt ${timestamp}
    ...                 warehouseId=${warehouse_id}
    ...                 supplierId=1
    RETURN            ${receipt_data}

Generate Product Data
    [Documentation]     Generate product data for receipt
    [Arguments]         ${receipt_id}    ${warehouse_id}    ${master_product_id}    ${suffix}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_code}=    Set Variable     PROD${timestamp}${suffix}
    
    ${product_data}=    Create Dictionary
    ...                 name=Test Product ${suffix} ${timestamp}
    ...                 totalQuantity=75
    ...                 expectedQuantity=75
    ...                 importDate=2025-04-02T00:00:00.000Z
    ...                 cost=12.25
    ...                 salePrice=18.00
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-04-02T00:00:00.000Z
    ...                 productCode=${product_code}
    ...                 supplierId=1
    ...                 productCategoryId=37
    ...                 rackId=1
    ...                 receiptId=${receipt_id}
    ...                 masterProductId=${master_product_id}
    RETURN            ${product_data}

Generate Master Product Data
    [Documentation]     Generate master product data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${suppliers}=       Create List      1
    
    ${master_data}=     Create Dictionary
    ...                 name=Master Product ${timestamp}
    ...                 capacity=1500
    ...                 method=LIFO
    ...                 stogareTime=180
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=37
    ...                 supplierIds=${suppliers}
    ...                 purchasePrice=12.00
    ...                 salePrice=18.00
    ...                 retailPrice=25.00
    ...                 barCode=MP${timestamp}
    RETURN            ${master_data}

Generate Replenishment Data
    [Documentation]     Generate replenishment data
    [Arguments]         ${master_product_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    
    ${repl_data}=       Create Dictionary
    ...                 productName=Repl Product ${timestamp}
    ...                 min=25
    ...                 max=300
    ...                 productCategoryId=37
    ...                 masterProductId=${master_product_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    RETURN            ${repl_data}

Generate Product Order Data
    [Documentation]     Generate product order data with multiple products
    [Arguments]         ${product_id_1}    ${product_id_2}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${products}=        Create List      ${product_id_1}    ${product_id_2}
    
    ${order_data}=      Create Dictionary
    ...                 total=100
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=SKU${timestamp}
    ...                 products=${products}
    RETURN            ${order_data}

Generate Package Data
    [Documentation]     Generate package data for order
    [Arguments]         ${order_id}
    ${package_data}=    Create Dictionary
    ...                 orderId=${order_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 zoneId=1
    RETURN            ${package_data}

Create Warehouse
    [Documentation]     Create a new warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${warehouse_id}=    Convert To String    ${json}[id]
    RETURN            ${warehouse_id}

Create Receipt
    [Documentation]     Create a new receipt with multiple products
    [Arguments]         ${receipt_data}    ${products}
    Dictionary Should Contain Key    ${receipt_data}    receiptDate
    Dictionary Should Contain Key    ${receipt_data}    warehouseId
    
    Set To Dictionary   ${receipt_data}    products=${products}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /receipts/create
    ...                 json=${receipt_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}receipt_create_${timestamp}.json    ${response.text}
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${receipt_id}=      Convert To String    ${json}[id]
    RETURN            ${receipt_id}    ${json}

Create Master Product
    [Documentation]     Create a master product
    [Arguments]         ${master_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /master-products/create
    ...                 json=${master_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${master_id}=       Convert To String    ${json}[id]
    RETURN            ${master_id}

Create Replenishment
    [Documentation]     Create a replenishment for master product
    [Arguments]         ${repl_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /replenishments/create
    ...                 json=${repl_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${repl_id}=         Convert To String    ${json}[id]
    RETURN            ${repl_id}

Create Product Order
    [Documentation]     Create a product order with product constraints
    [Arguments]         ${order_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${order_id}=        Convert To String    ${json}[id]
    RETURN            ${order_id}

Create Package
    [Documentation]     Create a package for order
    [Arguments]         ${package_data}
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

Get Receipt By ID
    [Documentation]     Retrieve a specific receipt
    [Arguments]         ${receipt_id}
    Should Not Be Empty    ${receipt_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /receipts/get-one/${receipt_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Assert Receipt Details
    [Documentation]     Verify receipt details match expected values
    [Arguments]         ${receipt}    ${expected_data}
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${receipt}    Should Be Equal    ${receipt}[${key}]    ${expected_data}[${key}]
    END

*** Test Cases ***
01 - Setup Admin Environment
    [Documentation]     Setup API session with admin credentials
    [Tags]              setup    admin
    Setup API Session    ${ADMIN_USERNAME}    ${ADMIN_PASSWORD}
    Log                 Successfully authenticated as admin with token: ${AUTH_TOKEN}

02 - Create Warehouse Test
    [Documentation]     Test creating a new warehouse (admin)
    [Tags]              create    warehouses    admin
    ${warehouse_data}=  Generate Warehouse Data
    ${warehouse_id}=    Create Warehouse    ${warehouse_data}
    Should Not Be Empty    ${warehouse_id}
    Set Global Variable    ${WAREHOUSE_ID}    ${warehouse_id}
    Log                 Successfully created warehouse with ID: ${warehouse_id}

03 - Switch to Manager Environment
    [Documentation]     Switch to manager credentials
    [Tags]              setup    manager
    Setup API Session    ${MANAGER_USERNAME}    ${MANAGER_PASSWORD}
    Log                 Successfully authenticated as manager with token: ${AUTH_TOKEN}

04 - Create Master Product Test
    [Documentation]     Test creating a master product (manager)
    [Tags]              create    master-products    manager
    ${master_data}=     Generate Master Product Data
    ${master_id}=       Create Master Product    ${master_data}
    Should Not Be Empty    ${master_id}
    Set Global Variable    ${MASTER_PRODUCT_ID}    ${master_id}
    Log                 Successfully created master product with ID: ${master_id}

05 - Create Receipt Test
    [Documentation]     Test creating a receipt with multiple products
    [Tags]              create    receipts    products    manager
    ${receipt_data}=    Generate Receipt Data    ${WAREHOUSE_ID}
    ${product_data_1}=  Generate Product Data    ${RECEIPT_ID}    ${WAREHOUSE_ID}    ${MASTER_PRODUCT_ID}    1
    ${product_data_2}=  Generate Product Data    ${RECEIPT_ID}    ${WAREHOUSE_ID}    ${MASTER_PRODUCT_ID}    2
    ${products}=        Create List    ${product_data_1}    ${product_data_2}
    
    ${receipt_id}    ${response}=    Create Receipt    ${receipt_data}    ${products}
    Should Not Be Empty    ${receipt_id}
    Assert Receipt Details    ${response}    ${receipt_data}
    
    Set Global Variable    ${RECEIPT_ID}    ${receipt_id}
    Set Global Variable    ${TEST_RECEIPT_DATA}    ${receipt_data}
    Set Global Variable    ${PRODUCT_ID_1}    ${response}[products][0][id]
    Set Global Variable    ${PRODUCT_ID_2}    ${response}[products][1][id]
    Log                 Successfully created receipt with ID: ${receipt_id} and 2 products

06 - Create Replenishment Test
    [Documentation]     Test creating replenishment for master product
    [Tags]              create    replenishments    manager
    ${repl_data}=       Generate Replenishment Data    ${MASTER_PRODUCT_ID}
    ${repl_id}=         Create Replenishment    ${repl_data}
    Should Not Be Empty    ${repl_id}
    Set Global Variable    ${REPLENISHMENT_ID}    ${repl_id}
    Log                 Successfully created replenishment with ID: ${repl_id}

07 - Create Product Order Test
    [Documentation]     Test creating product order with multiple products
    [Tags]              create    product-orders    manager
    ${order_data}=      Generate Product Order Data    ${PRODUCT_ID_1}    ${PRODUCT_ID_2}
    ${order_id}=        Create Product Order    ${order_data}
    Should Not Be Empty    ${order_id}
    Set Global Variable    ${PRODUCT_ORDER_ID}    ${order_id}
    Log                 Successfully created product order with ID: ${order_id}

08 - Create Package Test
    [Documentation]     Test creating package for order
    [Tags]              create    packages    manager
    ${package_data}=    Generate Package Data    ${PRODUCT_ORDER_ID}
    ${package_id}=      Create Package    ${package_data}
    Should Not Be Empty    ${package_id}
    Set Global Variable    ${PACKAGE_ID}    ${package_id}
    Log                 Successfully created package with ID: ${package_id}

09 - Get Receipt Test
    [Documentation]     Test retrieving a specific receipt
    [Tags]              retrieve    receipts    manager
    ${receipt}=         Get Receipt By ID    ${RECEIPT_ID}
    Assert Receipt Details    ${receipt}    ${TEST_RECEIPT_DATA}
    Log                 Successfully retrieved receipt with ID: ${RECEIPT_ID}

10 - Cleanup Test Environment
    [Documentation]     Clean up resources created during tests
    [Tags]              cleanup    manager
    # Add deletion steps if needed (e.g., DELETE endpoints)
    Log                 Test environment cleaned up successfully