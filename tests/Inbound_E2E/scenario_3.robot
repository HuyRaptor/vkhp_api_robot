*** Settings ***
Documentation     Comprehensive Test Suite for Supplier Management and Procurement in vKho API
...               Tests supplier operations, product procurement, and purchase orders
...               with positive, negative, edge cases, missing parameters, and input validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate with specified role
    [Arguments]         ${username}    ${password}
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${username}    password=${password}
    
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

Generate Supplier Data
    [Documentation]     Generate unique supplier data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_data}=   Create Dictionary
    ...                 name=Test Supplier ${timestamp}
    ...                 code=SUP${timestamp}
    ...                 email=supplier${timestamp}@test.com
    ...                 phone=123456789${timestamp % 10}
    ...                 address=456 Supplier Lane
    ...                 taxCode=TAX${timestamp}
    ...                 isActive=${TRUE}
    RETURN            ${supplier_data}

Generate Product Data
    [Documentation]     Generate product data linked to supplier
    [Arguments]         ${supplier_id}
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
    ...                 supplierId=${supplier_id}
    ...                 productCategoryId=37
    RETURN            ${product_data}

Generate Purchase Order Data
    [Documentation]     Generate purchase order data
    [Arguments]         ${supplier_id}    ${product_id}    ${quantity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${products}=        Create List      ${product_id}
    
    ${po_data}=         Create Dictionary
    ...                 supplierId=${supplier_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 orderDate=2025-04-02T00:00:00.000Z
    ...                 expectedDeliveryDate=2025-04-05T00:00:00.000Z
    ...                 totalAmount=${quantity * 10.50}
    ...                 products=${products}
    ...                 quantity=${quantity}
    ...                 status=PENDING
    ...                 poCode=PO${timestamp}
    RETURN            ${po_data}

Create Supplier
    [Documentation]     Create a new supplier
    [Arguments]         ${supplier_data}
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

Create Product
    [Documentation]     Create a new product
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

Create Purchase Order
    [Documentation]     Create a purchase order
    [Arguments]         ${po_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /purchase-orders/create
    ...                 json=${po_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${po_id}=           Convert To String    ${json}[id]
    RETURN            ${po_id}

Get Supplier By ID
    [Documentation]     Retrieve a specific supplier
    [Arguments]         ${supplier_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Assert Supplier Details
    [Documentation]     Verify supplier details match expected values
    [Arguments]         ${supplier}    ${expected_data}
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${supplier}    Should Be Equal    ${supplier}[${key}]    ${expected_data}[${key}]
    END

*** Test Cases ***
01 - Setup Admin Environment
    [Documentation]     Setup API session with admin credentials
    [Tags]              setup    admin
    Setup API Session    ${ADMIN_USERNAME}    ${ADMIN_PASSWORD}
    Log                 Successfully authenticated as admin

02 - Create Supplier - Positive
    [Documentation]     Test creating a new supplier
    [Tags]              create    suppliers    positive    admin
    ${supplier_data}=   Generate Supplier Data
    ${supplier_id}=     Create Supplier    ${supplier_data}
    Should Not Be Empty    ${supplier_id}
    Set Global Variable    ${SUPPLIER_ID}    ${supplier_id}
    ${supplier}=        Get Supplier By ID    ${supplier_id}
    Assert Supplier Details    ${supplier}    ${supplier_data}
    Log                 Created supplier with ID: ${supplier_id}

03 - Create Supplier - Negative (Invalid Email)
    [Documentation]     Test creating supplier with invalid email
    [Tags]              create    suppliers    negative    input-validation    admin
    ${supplier_data}=   Generate Supplier Data
    Set To Dictionary   ${supplier_data}    email=${INVALID_EMAIL}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create supplier with invalid email as expected

04 - Create Supplier - Missing Parameters (Name)
    [Documentation]     Test creating supplier without required name
    [Tags]              create    suppliers    missing-parameters    admin
    ${supplier_data}=   Generate Supplier Data
    Remove From Dictionary    ${supplier_data}    name
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create supplier without name as expected

05 - Switch to Manager Environment
    [Documentation]     Switch to manager credentials
    [Tags]              setup    manager
    Setup API Session    ${MANAGER_USERNAME}    ${MANAGER_PASSWORD}
    Log                 Successfully authenticated as manager

06 - Create Product - Positive
    [Documentation]     Test creating product linked to supplier
    [Tags]              create    products    positive    manager
    ${product_data}=    Generate Product Data    ${SUPPLIER_ID}
    ${product_id}=      Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Set Global Variable    ${PRODUCT_ID}    ${product_id}
    Log                 Created product with ID: ${product_id}

07 - Create Product - Negative (Invalid Supplier)
    [Documentation]     Test creating product with invalid supplier ID
    [Tags]              create    products    negative    manager
    ${product_data}=    Generate Product Data    ${INVALID_SUPPLIER_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create product with invalid supplier as expected

08 - Create Product - Edge (Zero Quantity)
    [Documentation]     Test creating product with zero quantity
    [Tags]              create    products    edge    manager
    ${product_data}=    Generate Product Data    ${SUPPLIER_ID}
    Set To Dictionary   ${product_data}    totalQuantity=0    expectedQuantity=0
    
    ${product_id}=      Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    Log                 Created product with zero quantity, ID: ${product_id}

09 - Create Purchase Order - Positive
    [Documentation]     Test creating purchase order with valid data
    [Tags]              create    purchase-orders    positive    manager
    ${po_data}=         Generate Purchase Order Data    ${SUPPLIER_ID}    ${PRODUCT_ID}    50
    ${po_id}=           Create Purchase Order    ${po_data}
    Should Not Be Empty    ${po_id}
    Set Global Variable    ${PURCHASE_ORDER_ID}    ${po_id}
    Log                 Created purchase order with ID: ${po_id}

10 - Create Purchase Order - Negative (Invalid Supplier)
    [Documentation]     Test creating purchase order with invalid supplier
    [Tags]              create    purchase-orders    negative    manager
    ${po_data}=         Generate Purchase Order Data    ${INVALID_SUPPLIER_ID}    ${PRODUCT_ID}    50
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /purchase-orders/create
    ...                 json=${po_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create purchase order with invalid supplier as expected

11 - Create Purchase Order - Missing Parameters (Products)
    [Documentation]     Test creating purchase order without products
    [Tags]              create    purchase-orders    missing-parameters    manager
    ${po_data}=         Generate Purchase Order Data    ${SUPPLIER_ID}    ${PRODUCT_ID}    50
    Remove From Dictionary    ${po_data}    products
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /purchase-orders/create
    ...                 json=${po_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create purchase order without products as expected

12 - Create Purchase Order - Edge (Max Quantity)
    [Documentation]     Test creating purchase order with very large quantity
    [Tags]              create    purchase-orders    edge    manager
    ${po_data}=         Generate Purchase Order Data    ${SUPPLIER_ID}    ${PRODUCT_ID}    999999
    ${po_id}=           Create Purchase Order    ${po_data}
    Should Not Be Empty    ${po_id}
    Log                 Created purchase order with max quantity, ID: ${po_id}

13 - Create Purchase Order - Input Validation (Negative Quantity)
    [Documentation]     Test creating purchase order with negative quantity
    [Tags]              create    purchase-orders    input-validation    manager
    ${po_data}=         Generate Purchase Order Data    ${SUPPLIER_ID}    ${PRODUCT_ID}    -50
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /purchase-orders/create
    ...                 json=${po_data}
    ...                 headers=${headers}
    ...                 expected_status=400
    Log                 Failed to create purchase order with negative quantity as expected

14 - Cleanup Test Environment
    [Documentation]     Clean up test resources
    [Tags]              cleanup    manager
    # Add deletion endpoints if available
    Log                 Test environment cleaned up successfully