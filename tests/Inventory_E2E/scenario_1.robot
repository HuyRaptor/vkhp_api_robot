*** Settings ***
Documentation     Refactored End-to-End Test Suite for Inventory Management
...               Tests product creation, rack assignment, splitting, and master product management
...               Includes positive, negative, missing parameters, and edge case validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${MANAGER_USERNAME}     huynh22.manager
${MANAGER_PASSWORD}     Snowfox1991
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_MASTER_PRODUCT_ID}    ${EMPTY}
${TEST_PRODUCT_ID}           ${EMPTY}
${TEST_WAREHOUSE_ID}         ${EMPTY}
${TEST_RACK_ID}              ${EMPTY}
${MAX_QUANTITY}              10000   # Maximum product quantity
${MIN_QUANTITY}              1      # Minimum product quantity
${CURRENT_DATE}              2025-04-02T00:00:00Z    # Fixed date for testing

*** Keywords ***
Setup Manager Session
    [Documentation]     Create API session and authenticate with manager credentials
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
    Set Global Variable  ${MANAGER_TOKEN}    ${token}
    Create Directory    ${RESULTS_DIR}

Generate Master Product Data
    [Documentation]     Generate master product data with required fields
    [Arguments]         ${name}=${NONE}    ${barcode}=${NONE}    ${method}=FIFO
    ${timestamp}=       Evaluate         int(time.time())    time
    ${master_data}=     Create Dictionary
    ...                 name=${name if name is not NONE else "Master Product ${timestamp}"}
    ...                 capacity=500
    ...                 method=${method}
    ...                 stogareTime=30
    ...                 image=https://example.com/image.jpg
    ...                 warehouseId=${TEST_WAREHOUSE_ID}
    ...                 productCategoryId=1
    ...                 supplierIds=[1]
    ...                 purchasePrice=20.00
    ...                 salePrice=49.99
    ...                 retailPrice=59.99
    ...                 barCode=${barcode if barcode is not NONE else "BAR-${timestamp}"}
    ...                 VAT=10
    ...                 DVT=unit
    ...                 packing=box
    ...                 length=10
    ...                 width=10
    ...                 height=10
    ...                 itemCode=ITEM-${timestamp}
    ...                 description=Test master product
    ...                 isActive=${TRUE}
    ...                 discount=0
    ...                 isResources=${FALSE}
    ...                 availableQuantity=1000
    RETURN            ${master_data}

Generate Product Data
    [Documentation]     Generate product data with required fields
    [Arguments]         ${master_product_id}    ${quantity}=1000    ${product_code}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Product ${timestamp}
    ...                 totalQuantity=${quantity}
    ...                 expectedQuantity=${quantity}
    ...                 importDate=${CURRENT_DATE}
    ...                 cost=20.00
    ...                 salePrice=49.99
    ...                 warehouseId=${TEST_WAREHOUSE_ID}
    ...                 inboundKind=NEW
    ...                 expireDate=2025-12-31T00:00:00Z
    ...                 productCode=${product_code if product_code is not NONE else "PROD-${timestamp}"}
    ...                 idRackReallocate=${TEST_RACK_ID}
    ...                 imageProduct=https://example.com/product.jpg
    ...                 imageQRCode=https://example.com/qr.jpg
    ...                 imageBarcode=https://example.com/barcode.jpg
    ...                 blockId=1
    ...                 supplierId=1
    ...                 productCategoryId=1
    ...                 rackId=${TEST_RACK_ID}
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=1
    ...                 packageId=1
    ...                 masterProductId=${master_product_id}
    ...                 note=Test product
    ...                 barCode=BAR-${timestamp}
    RETURN            ${product_data}

Generate Warehouse Data
    [Documentation]     Generate minimal warehouse data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Test Warehouse ${timestamp}
    ...                 address=123 Test St
    ...                 acreage=5000
    RETURN            ${warehouse_data}

Generate Rack Data
    [Documentation]     Generate minimal rack data
    ${rack_data}=      Create Dictionary
    ...                 capacity=${MAX_QUANTITY}
    ...                 warehouseId=${TEST_WAREHOUSE_ID}
    ...                 shelfId=1
    RETURN            ${rack_data}

Create Master Product
    [Documentation]     Create a new master product
    [Arguments]         ${master_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /master-products/create
    ...                 json=${master_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Create Product
    [Documentation]     Create a new product instance
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Create Warehouse
    [Documentation]     Create a new warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Rack
    [Documentation]     Create a new rack
    [Arguments]         ${rack_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Split Product
    [Documentation]     Split product quantity
    [Arguments]         ${product_id}    ${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${split_data}=      Create Dictionary    id=${product_id}    quantity=${quantity}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/split
    ...                 json=${split_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Add Product To Rack
    [Documentation]     Assign products to a rack
    [Arguments]         ${rack_id}    ${product_ids}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${rack_data}=       Create Dictionary    rackId=${rack_id}    productIds=${product_ids}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/add/rack
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Get Inventory
    [Documentation]     Get inventory levels
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-inventory
    ...                 params=warehouseId=${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Delete Product
    [Documentation]     Delete a product instance
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete MasterProduct
    [Documentation]     Delete a master product
    [Arguments]         ${master_product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /master-products/delete/${master_product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Rack
    [Documentation]     Delete a rack
    [Arguments]         ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Warehouse
    [Documentation]     Delete a warehouse
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Validate Inventory
    [Documentation]     Validate inventory quantity for a product
    [Arguments]         ${inventory}    ${product_id}    ${expected_quantity}
    ${found}=           Set Variable    ${FALSE}
    FOR    ${item}    IN    @{inventory}
        ${item_id}=     Evaluate    str(${item}[id]) if 'id' in ${item} else None
        IF    "${item_id}" == "${product_id}"
            ${actual_quantity}=    Set Variable    ${item}[totalQuantity]
            Should Be Equal As Integers    ${actual_quantity}    ${expected_quantity}
            ...                            Inventory quantity ${actual_quantity} does not match expected ${expected_quantity} for product ${product_id}
            ${found}=       Set Variable    ${TRUE}
            BREAK
        END
    END
    Should Be True    ${found}    Product ${product_id} not found in inventory

*** Test Cases ***
01 - Inventory Management with Product Lifecycle
    [Documentation]     End-to-end flow for inventory with product creation, splitting, and rack assignment
    [Tags]              inventory    products    master-products    validation

    Setup Manager Session
    Log                 Manager authentication completed

    # Setup Warehouse and Rack
    ${warehouse_data}=    Generate Warehouse Data
    ${warehouse_id}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Log                 Created warehouse: ${warehouse_id}

    ${rack_data}=    Generate Rack Data
    ${rack_id}    ${rack_response}=    Create Rack    ${rack_data}
    Set Global Variable  ${TEST_RACK_ID}    ${rack_id}
    Log                 Created rack: ${rack_id}

    # Positive - Create Master Product
    ${master_data}=    Generate Master Product Data
    ${status_m1}    ${master_response1}=    Create Master Product    ${master_data}
    Should Be Equal As Integers    ${status_m1}    201
    Set Global Variable  ${TEST_MASTER_PRODUCT_ID}    ${master_response1}[id]
    Log                 Created master product: ${TEST_MASTER_PRODUCT_ID}

    # Positive - Create Product
    ${product_data}=    Generate Product Data    ${TEST_MASTER_PRODUCT_ID}
    ${status_p1}    ${product_response1}=    Create Product    ${product_data}
    Should Be Equal As Integers    ${status_p1}    201
    Set Global Variable  ${TEST_PRODUCT_ID}    ${product_response1}[id]
    Log                 Created product: ${TEST_PRODUCT_ID}

    # Negative - Missing Required Field (productCode)
    ${no_code_data}=    Generate Product Data    ${TEST_MASTER_PRODUCT_ID}
    Remove From Dictionary    ${no_code_data}    productCode
    ${status_p2}    ${product_response2}=    Create Product    ${no_code_data}
    Should Be Equal As Integers    ${status_p2}    400
    Should Contain    ${product_response2}[message]    productCode    ignore_case=True
    Log                 Prevented product creation with missing productCode

    # Edge Case - Minimum Quantity
    ${min_qty_data}=    Generate Product Data    ${TEST_MASTER_PRODUCT_ID}    quantity=${MIN_QUANTITY}
    ${status_p3}    ${product_response3}=    Create Product    ${min_qty_data}
    Should Be Equal As Integers    ${status_p3}    201
    ${min_qty_product_id}=    Set Variable    ${product_response3}[id]
    Log                 Created product with minimum quantity: ${min_qty_product_id}

    # Positive - Add Product to Rack
    ${status_rack1}    ${rack_response1}=    Add Product To Rack    ${TEST_RACK_ID}    [${TEST_PRODUCT_ID}]
    Should Be Equal As Integers    ${status_rack1}    201
    Log                 Assigned product ${TEST_PRODUCT_ID} to rack ${TEST_RACK_ID}

    # Negative - Invalid Rack ID
    ${status_rack2}    ${rack_response2}=    Add Product To Rack    9999    [${TEST_PRODUCT_ID}]
    Should Be Equal As Integers    ${status_rack2}    404
    Should Contain    ${rack_response2}[message]    not found    ignore_case=True
    Log                 Prevented assignment to invalid rack

    # Positive - Split Product
    ${status_split1}    ${split_response1}=    Split Product    ${TEST_PRODUCT_ID}    500
    Should Be Equal As Integers    ${status_split1}    201
    ${split_product_id}=    Set Variable    ${split_response1}[id]
    Log                 Split product ${TEST_PRODUCT_ID} into new product ${split_product_id} with 500 units

    # Negative - Split Exceeding Quantity
    ${status_split2}    ${split_response2}=    Split Product    ${TEST_PRODUCT_ID}    1000
    Should Be Equal As Integers    ${status_split2}    400
    Should Contain    ${split_response2}[message]    quantity    ignore_case=True
    Log                 Prevented split exceeding remaining quantity

    # Edge Case - Split to Minimum Quantity
    ${status_split3}    ${split_response3}=    Split Product    ${min_qty_product_id}    ${MIN_QUANTITY}
    Should Be Equal As Integers    ${status_split3}    201
    ${min_split_product_id}=    Set Variable    ${split_response3}[id]
    Log                 Split minimum quantity product ${min_qty_product_id} into ${min_split_product_id}

    # Positive - Validate Inventory
    ${status_inv1}    ${inventory1}=    Get Inventory    ${TEST_WAREHOUSE_ID}
    Should Be Equal As Integers    ${status_inv1}    200
    Validate Inventory    ${inventory1}    ${TEST_PRODUCT_ID}    500
    Validate Inventory    ${inventory1}    ${split_product_id}    500
    Validate Inventory    ${inventory1}    ${min_qty_product_id}    0
    Log                 Validated inventory levels

    # Negative - Inventory Missing Warehouse ID
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-inventory
    ...                 headers=${headers}
    ...                 expected_status=400
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    warehouseId    ignore_case=True
    Log                 Prevented inventory retrieval without warehouse ID

    # Cleanup
    Delete Product    ${TEST_PRODUCT_ID}
    Delete Product    ${split_product_id}
    Delete Product    ${min_qty_product_id}
    Delete Product    ${min_split_product_id}
    Delete MasterProduct    ${TEST_MASTER_PRODUCT_ID}
    Delete Rack    ${TEST_RACK_ID}
    Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Log                 Successfully cleaned up all resources