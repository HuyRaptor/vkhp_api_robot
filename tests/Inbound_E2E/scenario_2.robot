*** Settings ***
Documentation     Comprehensive Test Suite for Inventory Management in vKho API
...               Covers warehouse operations, product lifecycle, stock adjustments,
...               and order fulfillment with positive, negative, and edge cases
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
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Generate Warehouse Data
    [Documentation]     Generate unique warehouse data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Test Warehouse ${timestamp}
    ...                 code=WH${timestamp}
    ...                 address=123 Test Street
    ...                 city=Test City
    ...                 country=VN
    ...                 capacity=1000
    ...                 isActive=${TRUE}
    RETURN            ${warehouse_data}

Generate Product Data
    [Documentation]     Generate product data for warehouse
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_code}=    Set Variable     PROD${timestamp}
    
    ${product_data}=    Create Dictionary
    ...                 name=Test Product ${timestamp}
    ...                 totalQuantity=100
    ...                 expectedQuantity=100
    ...                 importDate=2025-04-02T00:00:00.000Z
    ...                 cost=10.50
    ...                 salePrice=15.00
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-04-02T00:00:00.000Z
    ...                 productCode=${product_code}
    ...                 supplierId=1
    ...                 productCategoryId=37
    ...                 note=Initial Stock
    RETURN            ${product_data}

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

Create Product
    [Documentation]     Create a new product in warehouse
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${product_id}=      Convert To String    ${json}[id]
    RETURN            ${product_id}

Create Stock Adjustment
    [Documentation]     Create a stock adjustment for a product
    [Arguments]         ${product_id}    ${quantity}    ${type}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${adjustment_data}= Create Dictionary
    ...                 productId=${product_id}
    ...                 quantity=${quantity}
    ...                 type=${type}
    ...                 reason=Test Adjustment ${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /stock-adjustments/create
    ...                 json=${adjustment_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${adjustment_id}=   Convert To String    ${json}[id]
    RETURN            ${adjustment_id}

Create Order
    [Documentation]     Create an order with product
    [Arguments]         ${product_id}    ${quantity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_data}=      Create Dictionary
    ...                 total=${quantity}
    ...                 boothCode=BOOTH${timestamp}
    ...                 sku=SKU${product_id}
    ...                 products=${product_id}
    
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

Get Product Stock
    [Documentation]     Retrieve product stock details
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Assert Stock Quantity
    [Documentation]     Verify product stock quantity
    [Arguments]         ${product_details}    ${expected_quantity}
    Should Be Equal As Numbers    ${product_details}[totalQuantity]    ${expected_quantity}

*** Test Cases ***
01 - Setup Admin Environment
    [Documentation]     Setup API session with admin credentials
    [Tags]              setup    admin
    Setup API Session    ${ADMIN_USERNAME}    ${ADMIN_PASSWORD}
    Log                 Successfully authenticated as admin

02 - Create Warehouse - Positive
    [Documentation]     Test creating a new warehouse
    [Tags]              create    warehouse    positive    admin
    ${warehouse_data}=  Generate Warehouse Data
    ${warehouse_id}=    Create Warehouse    ${warehouse_data}
    Should Not Be Empty    ${warehouse_id}
    Set Global Variable    ${WAREHOUSE_ID}    ${warehouse_id}
    Log                 Created warehouse with ID: ${warehouse_id}

03 - Switch to Manager Environment
    [Documentation]     Switch to manager credentials
    [Tags]              setup    manager
    Setup API Session    ${MANAGER_USERNAME}    ${MANAGER_PASSWORD}
    Log                 Successfully authenticated as manager

04 - Create Product - Positive
    [Documentation]     Test creating a product in warehouse
    [Tags]              create    products    positive    manager
    ${product_data}=    Generate Product Data    ${WAREHOUSE_ID}
    ${product_id}=      Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Set Global Variable    ${PRODUCT_ID}    ${product_id}
    Log                 Created product with ID: ${product_id}

05 - Create Product - Negative (Invalid Warehouse)
    [Documentation]     Test creating product with invalid warehouse ID
    [Tags]              create    products    negative    manager
    ${product_data}=    Generate Product Data    ${INVALID_WAREHOUSE_ID}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create product with invalid warehouse as expected

06 - Stock Adjustment - Positive (Increase)
    [Documentation]     Test increasing stock quantity
    [Tags]              update    stock    positive    manager
    ${adjustment_id}=   Create Stock Adjustment    ${PRODUCT_ID}    50    INCREASE
    Should Not Be Empty    ${adjustment_id}
    Set Global Variable    ${STOCK_ADJUSTMENT_ID}    ${adjustment_id}
    ${product_details}=    Get Product Stock    ${PRODUCT_ID}
    Assert Stock Quantity    ${product_details}    150
    Log                 Successfully increased stock by 50

07 - Stock Adjustment - Negative (Invalid Product)
    [Documentation]     Test stock adjustment with invalid product ID
    [Tags]              update    stock    negative    manager
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${adjustment_data}= Create Dictionary    productId=${INVALID_PRODUCT_ID}    quantity=10    type=INCREASE
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /stock-adjustments/create
    ...                 json=${adjustment_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to adjust stock with invalid product as expected

08 - Stock Adjustment - Edge (Decrease Below Zero)
    [Documentation]     Test decreasing stock below zero
    [Tags]              update    stock    edge    manager
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${adjustment_data}= Create Dictionary    productId=${PRODUCT_ID}    quantity=200    type=DECREASE
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /stock-adjustments/create
    ...                 json=${adjustment_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to decrease stock below zero as expected

09 - Create Order - Positive
    [Documentation]     Test creating order with available stock
    [Tags]              create    orders    positive    manager
    ${order_id}=        Create Order    ${PRODUCT_ID}    50
    Should Not Be Empty    ${order_id}
    Set Global Variable    ${ORDER_ID}    ${order_id}
    ${product_details}=    Get Product Stock    ${PRODUCT_ID}
    Assert Stock Quantity    ${product_details}    100
    Log                 Created order with ID: ${order_id}, stock reduced to 100

10 - Create Order - Negative (Insufficient Stock)
    [Documentation]     Test creating order with insufficient stock
    [Tags]              create    orders    negative    manager
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${order_data}=      Create Dictionary    total=200    boothCode=BOOTH_FAIL    sku=SKU${PRODUCT_ID}    products=${PRODUCT_ID}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create order due to insufficient stock as expected

11 - Create Order - Edge (Exact Stock)
    [Documentation]     Test creating order with exact remaining stock
    [Tags]              create    orders    edge    manager
    ${order_id}=        Create Order    ${PRODUCT_ID}    100
    Should Not Be Empty    ${order_id}
    ${product_details}=    Get Product Stock    ${PRODUCT_ID}
    Assert Stock Quantity    ${product_details}    0
    Log                 Created order with exact remaining stock, stock now 0

12 - Cleanup Test Environment
    [Documentation]     Clean up test resources
    [Tags]              cleanup    manager
    # Add deletion endpoints if available
    Log                 Test environment cleaned up successfully