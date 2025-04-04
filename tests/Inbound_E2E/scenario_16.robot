*** Settings ***
Documentation     Comprehensive Test Suite for Receipt Operations with Product Constraints in vKho API
...               Includes product management, master products, replenishments, and package handling with warehouse integration
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session As Admin
    [Documentation]     Create API session and authenticate as admin
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${ADMIN_USERNAME}    password=${ADMIN_PASSWORD}
    
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
    Set Global Variable  ${ADMIN_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Setup API Session As Manager
    [Documentation]     Create API session and authenticate as manager
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
    ...    msg=Authentication failed: Response did not contain access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}

Generate Unique Product Data
    [Documentation]     Generate unique data for product tests
    ${timestamp}=       Get Time    epoch
    ${sku}=             Set Variable    PSKU${timestamp}
    ${name}=            Set Variable    Test Product ${timestamp}
    
    ${product_data}=    Create Dictionary
    ...                 sku=${sku}
    ...                 name=${name}
    ...                 description=Test Product Description
    ...                 unit=PIECE
    ...                 status=${PRODUCT_STATUS_ENABLE}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 minQuantity=20
    ...                 maxQuantity=2000
    ...                 reorderPoint=100
    
    RETURN            ${product_data}

Create Product
    [Documentation]     Create a new product
    [Arguments]         ${product_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${product_data}    sku
    ...    msg=Missing required field: sku
    Dictionary Should Contain Key    ${product_data}    name
    ...    msg=Missing required field: name
    Dictionary Should Contain Key    ${product_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Generate Unique Master Product Data
    [Documentation]     Generate unique data for master product tests
    ${timestamp}=       Get Time    epoch
    ${sku}=             Set Variable    MSKU${timestamp}
    ${name}=            Set Variable    Test Master Product ${timestamp}
    
    ${master_data}=     Create Dictionary
    ...                 sku=${sku}
    ...                 name=${name}
    ...                 description=Test Master Product Description
    ...                 unit=PIECE
    ...                 status=${MASTER_STATUS_ENABLE}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 minQuantity=40
    ...                 maxQuantity=4000
    ...                 reorderPoint=200
    
    RETURN            ${master_data}

Create Master Product
    [Documentation]     Create a new master product
    [Arguments]         ${master_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${master_data}    sku
    ...    msg=Missing required field: sku
    Dictionary Should Contain Key    ${master_data}    name
    ...    msg=Missing required field: name
    Dictionary Should Contain Key    ${master_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /master-products/create
    ...                 json=${master_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Generate Unique Replenishment Data
    [Documentation]     Generate unique data for replenishment tests
    [Arguments]         ${master_id}
    
    ${timestamp}=       Get Time    epoch
    ${replenish_code}=  Set Variable    REP${timestamp}
    
    ${replenish_data}=  Create Dictionary
    ...                 code=${replenish_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${REPLENISH_STATUS_NEW}
    ...                 note=Test Replenishment Note
    ...                 masterProductId=${master_id}
    ...                 quantity=400
    ...                 unitPrice=150
    ...                 total=60000
    ...                 expectedDate=${timestamp}
    ...                 priority=HIGH
    
    RETURN            ${replenish_data}

Create Replenishment
    [Documentation]     Create a new replenishment
    [Arguments]         ${replenish_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${replenish_data}    code
    ...    msg=Missing required field: code
    Dictionary Should Contain Key    ${replenish_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    Dictionary Should Contain Key    ${replenish_data}    masterProductId
    ...    msg=Missing required field: masterProductId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /replenishments/create
    ...                 json=${replenish_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Generate Unique Product Order Data
    [Documentation]     Generate unique data for product order tests
    [Arguments]         ${master_id}    ${product_id}
    
    ${timestamp}=       Get Time    epoch
    ${order_code}=      Set Variable    PO${timestamp}
    
    ${product_order}=   Create Dictionary
    ...                 masterProductId=${master_id}
    ...                 productId=${product_id}
    ...                 quantity=40
    ...                 unitPrice=250
    ...                 total=10000
    ...                 priority=HIGH
    ...                 expectedDate=${timestamp}
    
    ${product_orders}=  Create List      ${product_order}
    
    ${order_data}=      Create Dictionary
    ...                 code=${order_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${PRODUCT_ORDER_STATUS_NEW}
    ...                 note=Test Product Order Note
    ...                 productOrders=${product_orders}
    ...                 priority=HIGH
    
    RETURN            ${order_data}

Create Product Order
    [Documentation]     Create a new product order
    [Arguments]         ${order_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required field: code
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    Dictionary Should Contain Key    ${order_data}    productOrders
    ...    msg=Missing required field: productOrders
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Generate Unique Receipt Data
    [Documentation]     Generate unique data for receipt tests
    [Arguments]         ${replenish_id}
    
    ${timestamp}=       Get Time    epoch
    ${receipt_code}=    Set Variable    RCP${timestamp}
    
    ${receipt_data}=    Create Dictionary
    ...                 code=${receipt_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${RECEIPT_STATUS_NEW}
    ...                 note=Test Receipt Note
    ...                 replenishmentId=${replenish_id}
    ...                 priority=HIGH
    ...                 expectedDate=${timestamp}
    
    RETURN            ${receipt_data}

Create Receipt
    [Documentation]     Create a new receipt
    [Arguments]         ${receipt_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${receipt_data}    code
    ...    msg=Missing required field: code
    Dictionary Should Contain Key    ${receipt_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    Dictionary Should Contain Key    ${receipt_data}    replenishmentId
    ...    msg=Missing required field: replenishmentId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /receipts/create
    ...                 json=${receipt_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Create Package
    [Documentation]     Create a new package
    [Arguments]         ${package_data}
    
    # Validate required fields
    Dictionary Should Contain Key    ${package_data}    warehouseId
    ...    msg=Missing required field: warehouseId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /packages/create
    ...                 json=${package_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    RETURN            ${json}[id]    ${json}

Get Product By ID
    [Documentation]     Get a product by ID
    [Arguments]         ${product_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Get Master Product By ID
    [Documentation]     Get a master product by ID
    [Arguments]         ${master_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /master-products/get-one/${master_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Delete Product
    [Documentation]     Delete a product
    [Arguments]         ${product_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Master Product
    [Documentation]     Delete a master product
    [Arguments]         ${master_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /master-products/delete/${master_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Replenishment
    [Documentation]     Delete a replenishment
    [Arguments]         ${replenish_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /replenishments/delete/${replenish_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Product Order
    [Documentation]     Delete a product order
    [Arguments]         ${order_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /product-orders/delete/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Receipt
    [Documentation]     Delete a receipt
    [Arguments]         ${receipt_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /receipts/delete/${receipt_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Package
    [Documentation]     Delete a package
    [Arguments]         ${package_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /packages/delete/${package_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API sessions for both admin and manager
    [Tags]              setup
    Setup API Session As Admin
    Setup API Session As Manager
    Log                 Successfully authenticated as both admin and manager

02 - Create Product With Constraints Test
    [Documentation]     Test creating a new product with quantity constraints
    [Tags]              product    create    positive
    
    ${product_data}=    Generate Unique Product Data
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    Should Not Be Empty    ${product_id}
    Should Be Equal     ${response}[sku]    ${product_data}[sku]
    Should Be Equal     ${response}[minQuantity]    ${product_data}[minQuantity]
    Should Be Equal     ${response}[maxQuantity]    ${product_data}[maxQuantity]
    Should Be Equal     ${response}[reorderPoint]    ${product_data}[reorderPoint]
    
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}
    
    Log                 Successfully created product with constraints: ${response}[name] with ID: ${TEST_PRODUCT_ID}

03 - Create Master Product With Constraints Test
    [Documentation]     Test creating a new master product with quantity constraints
    [Tags]              master    create    positive
    
    ${master_data}=     Generate Unique Master Product Data
    ${master_id}    ${response}=    Create Master Product    ${master_data}
    
    Should Not Be Empty    ${master_id}
    Should Be Equal     ${response}[sku]    ${master_data}[sku]
    Should Be Equal     ${response}[minQuantity]    ${master_data}[minQuantity]
    Should Be Equal     ${response}[maxQuantity]    ${master_data}[maxQuantity]
    Should Be Equal     ${response}[reorderPoint]    ${master_data}[reorderPoint]
    
    Set Global Variable  ${TEST_MASTER_ID}      ${master_id}
    Set Global Variable  ${TEST_MASTER_DATA}    ${master_data}
    
    Log                 Successfully created master product with constraints: ${response}[name] with ID: ${TEST_MASTER_ID}

04 - Create Replenishment With Priority Test
    [Documentation]     Test creating a new replenishment with priority
    [Tags]              replenish    create    positive
    
    Run Keyword If      "${TEST_MASTER_ID}" == "${EMPTY}"    Create Master Product With Constraints Test
    
    ${replenish_data}=  Generate Unique Replenishment Data    ${TEST_MASTER_ID}
    ${replenish_id}    ${response}=    Create Replenishment    ${replenish_data}
    
    Should Not Be Empty    ${replenish_id}
    Should Be Equal     ${response}[code]    ${replenish_data}[code]
    Should Be Equal     ${response}[masterProductId]    ${TEST_MASTER_ID}
    Should Be Equal     ${response}[priority]    ${replenish_data}[priority]
    
    Set Global Variable  ${TEST_REPLENISH_ID}      ${replenish_id}
    Set Global Variable  ${TEST_REPLENISH_DATA}    ${replenish_data}
    
    Log                 Successfully created high priority replenishment: ${response}[code] with ID: ${TEST_REPLENISH_ID}

05 - Create Product Order With Constraints Test
    [Documentation]     Test creating a new product order with product constraints
    [Tags]              order    create    positive
    
    Run Keyword If      "${TEST_MASTER_ID}" == "${EMPTY}"    Create Master Product With Constraints Test
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Product With Constraints Test
    
    ${order_data}=      Generate Unique Product Order Data    ${TEST_MASTER_ID}    ${TEST_PRODUCT_ID}
    ${order_id}    ${response}=    Create Product Order    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal     ${response}[code]    ${order_data}[code]
    Should Be Equal     ${response}[priority]    ${order_data}[priority]
    
    # Verify product order constraints
    ${product_order}=   Get From List    ${response}[productOrders]    0
    Should Be True      ${product_order}[quantity] >= ${TEST_PRODUCT_DATA}[minQuantity]
    ...    msg=Product order quantity is below minimum quantity
    Should Be True      ${product_order}[quantity] <= ${TEST_PRODUCT_DATA}[maxQuantity]
    ...    msg=Product order quantity exceeds maximum quantity
    
    Set Global Variable  ${TEST_PRODUCT_ORDER_ID}      ${order_id}
    Set Global Variable  ${TEST_PRODUCT_ORDER_DATA}    ${order_data}
    
    Log                 Successfully created product order with constraints: ${response}[code] with ID: ${TEST_PRODUCT_ORDER_ID}

06 - Create Receipt With Priority Test
    [Documentation]     Test creating a new receipt with priority
    [Tags]              receipt    create    positive
    
    Run Keyword If      "${TEST_REPLENISH_ID}" == "${EMPTY}"    Create Replenishment With Priority Test
    
    ${receipt_data}=    Generate Unique Receipt Data    ${TEST_REPLENISH_ID}
    ${receipt_id}    ${response}=    Create Receipt    ${receipt_data}
    
    Should Not Be Empty    ${receipt_id}
    Should Be Equal     ${response}[code]    ${receipt_data}[code]
    Should Be Equal     ${response}[replenishmentId]    ${TEST_REPLENISH_ID}
    Should Be Equal     ${response}[priority]    ${receipt_data}[priority]
    
    Set Global Variable  ${TEST_RECEIPT_ID}      ${receipt_id}
    Set Global Variable  ${TEST_RECEIPT_DATA}    ${receipt_data}
    
    Log                 Successfully created high priority receipt: ${response}[code] with ID: ${TEST_RECEIPT_ID}

07 - Create Package With Priority Test
    [Documentation]     Test creating a new package with priority
    [Tags]              package    create    positive
    
    ${package_data}=    Create Dictionary
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${PACKAGE_STATUS_NEW}
    ...                 note=Test Package Note
    ...                 receiptId=${TEST_RECEIPT_ID}
    ...                 priority=HIGH
    
    ${package_id}    ${response}=    Create Package    ${package_data}
    
    Should Not Be Empty    ${package_id}
    Should Be Equal     ${response}[warehouseId]    ${WAREHOUSE_ID}
    Should Be Equal     ${response}[receiptId]    ${TEST_RECEIPT_ID}
    Should Be Equal     ${response}[priority]    ${package_data}[priority]
    
    Set Global Variable  ${TEST_PACKAGE_ID}      ${package_id}
    Set Global Variable  ${TEST_PACKAGE_DATA}    ${package_data}
    
    Log                 Successfully created high priority package with ID: ${TEST_PACKAGE_ID}

08 - Verify Product Constraints Test
    [Documentation]     Test verifying product quantity constraints
    [Tags]              product    validation    positive
    
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Product With Constraints Test
    
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    
    Should Be Equal     ${product}[minQuantity]    ${TEST_PRODUCT_DATA}[minQuantity]
    ...    msg=Product minimum quantity does not match
    Should Be Equal     ${product}[maxQuantity]    ${TEST_PRODUCT_DATA}[maxQuantity]
    ...    msg=Product maximum quantity does not match
    Should Be Equal     ${product}[reorderPoint]    ${TEST_PRODUCT_DATA}[reorderPoint]
    ...    msg=Product reorder point does not match
    
    Log                 Successfully verified product constraints

09 - Verify Master Product Constraints Test
    [Documentation]     Test verifying master product quantity constraints
    [Tags]              master    validation    positive
    
    Run Keyword If      "${TEST_MASTER_ID}" == "${EMPTY}"    Create Master Product With Constraints Test
    
    ${master}=          Get Master Product By ID    ${TEST_MASTER_ID}
    
    Should Be Equal     ${master}[minQuantity]    ${TEST_MASTER_DATA}[minQuantity]
    ...    msg=Master product minimum quantity does not match
    Should Be Equal     ${master}[maxQuantity]    ${TEST_MASTER_DATA}[maxQuantity]
    ...    msg=Master product maximum quantity does not match
    Should Be Equal     ${master}[reorderPoint]    ${TEST_MASTER_DATA}[reorderPoint]
    ...    msg=Master product reorder point does not match
    
    Log                 Successfully verified master product constraints

10 - Cleanup Test Environment
    [Documentation]     Clean up all test resources
    [Tags]              cleanup
    
    Run Keyword If      "${TEST_PACKAGE_ID}" != "${EMPTY}"
    ...                 Delete Package    ${TEST_PACKAGE_ID}
    Run Keyword If      "${TEST_RECEIPT_ID}" != "${EMPTY}"
    ...                 Delete Receipt    ${TEST_RECEIPT_ID}
    Run Keyword If      "${TEST_REPLENISH_ID}" != "${EMPTY}"
    ...                 Delete Replenishment    ${TEST_REPLENISH_ID}
    Run Keyword If      "${TEST_PRODUCT_ORDER_ID}" != "${EMPTY}"
    ...                 Delete Product Order    ${TEST_PRODUCT_ORDER_ID}
    Run Keyword If      "${TEST_MASTER_ID}" != "${EMPTY}"
    ...                 Delete Master Product    ${TEST_MASTER_ID}
    Run Keyword If      "${TEST_PRODUCT_ID}" != "${EMPTY}"
    ...                 Delete Product    ${TEST_PRODUCT_ID}
    
    Log                 Test environment cleaned up successfully
