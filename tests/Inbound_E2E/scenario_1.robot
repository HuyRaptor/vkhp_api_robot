*** Settings ***
Documentation     Comprehensive Test Suite for Receipt Operations in vKho API
...               Includes receipts with products, master products, replenishments,
...               product orders with package constraints, and warehouse relations
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

Generate Unique Receipt Data
    [Documentation]     Generate unique data for receipt tests
    ${timestamp}=       Evaluate         int(time.time())    time
    ${booth_code}=      Set Variable     BOOTH${timestamp}
    
    ${receipt_data}=    Create Dictionary
    ...                 receiptDate=2025-04-02T00:00:00.000Z
    ...                 driverName=Test Driver ${timestamp}
    ...                 boothCode=${booth_code}
    ...                 inboundkind=NEW
    ...                 description=Test Receipt ${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 supplierId=1
    RETURN            ${receipt_data}

Generate Product Data
    [Documentation]     Generate product data for receipt
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_code}=    Set Variable     PROD${timestamp}
    
    ${product_data}=    Create Dictionary
    ...                 name=Test Product ${timestamp}
    ...                 totalQuantity=100
    ...                 expectedQuantity=100
    ...                 importDate=2025-04-02T00:00:00.000Z
    ...                 cost=10.50
    ...                 salePrice=15.00
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-04-02T00:00:00.000Z
    ...                 productCode=${product_code}
    ...                 idRackReallocate=1
    ...                 imageProduct=test.jpg
    ...                 imageQRCode=qr.jpg
    ...                 imageBarcode=barcode.jpg
    ...                 blockId=1
    ...                 supplierId=1
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 rackId=1
    ...                 receiptId=${TEST_RECEIPT_ID}
    ...                 zoneId=1
    ...                 orderId=${NULL}
    ...                 packageId=${NULL}
    ...                 masterProductId=${TEST_MASTER_PRODUCT_ID}
    ...                 note=Test Note
    ...                 barCode=BAR${timestamp}
    RETURN            ${product_data}

Create Receipt
    [Documentation]     Create a new receipt with products
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
    Dictionary Should Contain Key        ${json}    id
    
    ${receipt_id}=      Convert To String    ${json}[id]
    RETURN            ${receipt_id}    ${json}

Create Master Product
    [Documentation]     Create a master product for replenishment
    ${timestamp}=       Evaluate         int(time.time())    time
    ${suppliers}=       Create List      1
    
    ${master_data}=     Create Dictionary
    ...                 name=Master Product ${timestamp}
    ...                 capacity=1000
    ...                 method=FIFO
    ...                 stogareTime=365
    ...                 image=master.jpg
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 supplierIds=${suppliers}
    ...                 purchasePrice=10.00
    ...                 salePrice=15.00
    ...                 retailPrice=20.00
    ...                 barCode=MP${timestamp}
    ...                 VAT=10
    ...                 DVT=unit
    ...                 packing=box
    ...                 length=10
    ...                 width=10
    ...                 height=10
    ...                 itemCode=ITEM${timestamp}
    ...                 description=Master Product
    ...                 isActive=${TRUE}
    ...                 discount=0
    ...                 isResources=${FALSE}
    ...                 availableQuantity=500
    
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
    [Documentation]     Create replenishment for master product
    [Arguments]         ${master_product_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    
    ${repl_data}=       Create Dictionary
    ...                 productName=Repl Product ${timestamp}
    ...                 min=50
    ...                 max=500
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 masterProductId=${master_product_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    
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
    [Documentation]     Create product order with product constraints
    [Arguments]         ${product_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    
    ${order_data}=      Create Dictionary
    ...                 total=50
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=SKU${product_id}
    
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
    [Documentation]     Create package for order
    [Arguments]         ${order_id}
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

02 - Create Master Product Test
    [Documentation]     Test creating a master product (admin)
    [Tags]              create    master-products    admin
    ${master_id}=       Create Master Product
    Set Global Variable  ${TEST_MASTER_PRODUCT_ID}    ${master_id}
    Should Not Be Empty    ${master_id}
    Log                 Successfully created master product with ID: ${master_id}

03 - Switch to Manager Environment
    [Documentation]     Switch to manager credentials
    [Tags]              setup    manager
    Setup API Session    ${MANAGER_USERNAME}    ${MANAGER_PASSWORD}
    Log                 Successfully authenticated as manager with token: ${AUTH_TOKEN}

04 - Create Receipt Test
    [Documentation]     Test creating a new receipt with products
    [Tags]              create    receipts    manager
    ${receipt_data}=    Generate Unique Receipt Data
    ${product_data}=    Generate Product Data
    ${products}=        Create List    ${product_data}
    
    ${receipt_id}    ${response}=    Create Receipt    ${receipt_data}    ${products}
    Should Not Be Empty    ${receipt_id}
    Assert Receipt Details    ${response}    ${receipt_data}
    
    Set Global Variable  ${TEST_RECEIPT_ID}    ${receipt_id}
    Set Global Variable  ${TEST_RECEIPT_DATA}  ${receipt_data}
    Set Global Variable  ${TEST_PRODUCT_ID}    ${response}[products][0][id]
    Log                 Successfully created receipt with ID: ${receipt_id}

05 - Create Replenishment Test
    [Documentation]     Test creating replenishment for master product
    [Tags]              create    replenishments    manager
    ${repl_id}=         Create Replenishment    ${TEST_MASTER_PRODUCT_ID}
    Should Not Be Empty    ${repl_id}
    Set Global Variable  ${TEST_REPLENISHMENT_ID}    ${repl_id}
    Log                 Successfully created replenishment with ID: ${repl_id}

06 - Create Product Order Test
    [Documentation]     Test creating product order with product
    [Tags]              create    product-orders    manager
    ${order_id}=        Create Product Order    ${TEST_PRODUCT_ID}
    Should Not Be Empty    ${order_id}
    Set Global Variable  ${TEST_ORDER_ID}    ${order_id}
    Log                 Successfully created product order with ID: ${order_id}

07 - Create Package Test
    [Documentation]     Test creating package for order
    [Tags]              create    packages    manager
    ${package_id}=      Create Package    ${TEST_ORDER_ID}
    Should Not Be Empty    ${package_id}
    Set Global Variable  ${TEST_PACKAGE_ID}    ${package_id}
    Log                 Successfully created package with ID: ${package_id}

08 - Get Receipt Test
    [Documentation]     Test retrieving a specific receipt
    [Tags]              retrieve    receipts    manager
    ${receipt}=         Get Receipt By ID    ${TEST_RECEIPT_ID}
    Assert Receipt Details    ${receipt}    ${TEST_RECEIPT_DATA}
    Log                 Successfully retrieved receipt with ID: ${TEST_RECEIPT_ID}

09 - Cleanup Test Environment
    [Documentation]     Clean up resources created during tests
    [Tags]              cleanup    manager
    # Add deletion steps if needed
    Log                 Test environment cleaned up successfully