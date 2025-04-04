*** Settings ***
Documentation     Comprehensive End-to-End Test Suite for Multi-Warehouse Inventory Management
...               Tests product lifecycle across warehouses, scanning, recommendations, and concurrent updates
...               Includes positive, negative, edge case, missing parameters, and concurrency validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Resource          ../../Variables/variables.robot

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

Generate Warehouse Data
    [Documentation]     Generate warehouse data
    [Arguments]         ${name_suffix}=${EMPTY}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Warehouse ${name_suffix} ${timestamp}
    ...                 address=123 Test St ${name_suffix}
    ...                 acreage=5000
    RETURN            ${warehouse_data}

Generate Rack Data
    [Documentation]     Generate rack data
    [Arguments]         ${warehouse_id}    ${capacity}=${MAX_CAPACITY}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Master Product Data
    [Documentation]     Generate master product data
    [Arguments]         ${warehouse_id}    ${name}=${NONE}    ${barcode}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${master_data}=     Create Dictionary
    ...                 name=${name if name is not NONE else "Master ${timestamp}"}
    ...                 capacity=500
    ...                 method=FIFO
    ...                 stogareTime=30
    ...                 image=https://example.com/image.jpg
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryId=1
    ...                 supplierIds=[1]
    ...                 purchasePrice=20.00
    ...                 salePrice=49.99
    ...                 retailPrice=59.99
    ...                 barCode=${barcode if barcode is not NONE else "BAR-M${timestamp}"}
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
    [Documentation]     Generate product data
    [Arguments]         ${warehouse_id}    ${master_id}    ${rack_id}    ${quantity}=1000    ${barcode}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Product ${timestamp}
    ...                 totalQuantity=${quantity}
    ...                 expectedQuantity=${quantity}
    ...                 importDate=${CURRENT_DATE}
    ...                 cost=20.00
    ...                 salePrice=49.99
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2025-12-31T00:00:00Z
    ...                 productCode=PROD-${timestamp}
    ...                 idRackReallocate=${rack_id}
    ...                 imageProduct=https://example.com/product.jpg
    ...                 imageQRCode=https://example.com/qr.jpg
    ...                 imageBarcode=https://example.com/barcode.jpg
    ...                 blockId=1
    ...                 supplierId=1
    ...                 productCategoryId=1
    ...                 rackId=${rack_id}
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=1
    ...                 packageId=1
    ...                 masterProductId=${master_id}
    ...                 note=Test product
    ...                 barCode=${barcode if barcode is not NONE else "BAR-P${timestamp}"}
    RETURN            ${product_data}

Create Warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /warehouses/create    json=${warehouse_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Rack
    [Arguments]         ${rack_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /racks/create    json=${rack_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Master Product
    [Arguments]         ${master_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /master-products/create    json=${master_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Create Product
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /products/create    json=${product_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Scan Product
    [Documentation]     Scan products for verification
    [Arguments]         ${warehouse_id}    ${product_codes}    ${barcodes}    ${rack_code}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${scan_data}=       Create Dictionary
    ...                 page=1
    ...                 limit=10
    ...                 startDate=${CURRENT_DATE}
    ...                 endDate=${CURRENT_DATE}
    ...                 sortBy=id
    ...                 sortDirection=desc
    ...                 warehouseId=${warehouse_id}
    ...                 productCodes=${product_codes}
    ...                 packageCodes=["PKG-001"]
    ...                 barCodes=${barcodes}
    ...                 rackCode=${rack_code}
    ...                 type=STORING
    ${response}=        POST On Session    vkho    /products/scan    json=${scan_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Recommend Products
    [Documentation]     Recommend products based on master product and quantity
    [Arguments]         ${master_id}    ${quantity}    ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${params}=          Create Dictionary    masterProductId=${master_id}    quantity=${quantity}    warehouseId=${warehouse_id}
    ${response}=        GET On Session    vkho    /products/recommend    params=${params}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Split Product
    [Arguments]         ${product_id}    ${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${split_data}=      Create Dictionary    id=${product_id}    quantity=${quantity}
    ${response}=        POST On Session    vkho    /products/split    json=${split_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Update Multiple Products
    [Documentation]     Update multiple products' status concurrently
    [Arguments]         ${product_ids}    ${status}    ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${update_data}=     Create Dictionary
    ...                 ids=${product_ids}
    ...                 status=${status}
    ...                 rackId=${rack_id}
    ...                 orderId=1
    ...                 group=TEST_GROUP
    ...                 packageCode=PKG-001
    ${response}=        POST On Session    vkho    /products/updates    json=${update_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Get Inventory
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session    vkho    /products/get-inventory    params=warehouseId=${warehouse_id}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Delete Product
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /products/delete/${product_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete MasterProduct
    [Arguments]         ${master_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /master-products/delete/${master_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete Rack
    [Arguments]         ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /racks/delete/${rack_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete Warehouse
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /warehouses/delete/${warehouse_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Validate Inventory
    [Arguments]         ${inventory}    ${product_id}    ${expected_quantity}
    ${found}=           Set Variable    ${FALSE}
    FOR    ${item}    IN    @{inventory}
        ${item_id}=     Evaluate    str(${item}[id]) if 'id' in ${item} else None
        IF    "${item_id}" == "${product_id}"
            ${actual_quantity}=    Set Variable    ${item}[totalQuantity]
            Should Be Equal As Integers    ${actual_quantity}    ${expected_quantity}
            ...                            Inventory mismatch: ${actual_quantity} vs ${expected_quantity} for ${product_id}
            ${found}=       Set Variable    ${TRUE}
            BREAK
        END
    END
    Should Be True    ${found}    Product ${product_id} not found in inventory

*** Test Cases ***
01 - Multi-Warehouse Inventory Management with Scanning and Recommendations
    [Documentation]     Complex test for multi-warehouse inventory with product lifecycle, scanning, and concurrent updates
    [Tags]              inventory    products    master-products    warehouse    validation

    Setup Manager Session
    Log                 Manager authenticated

    # Setup Warehouses and Racks
    ${wh1_data}=        Generate Warehouse Data    WH1
    ${wh1_id}    ${wh1_response}=    Create Warehouse    ${wh1_data}
    Set Global Variable  ${TEST_WAREHOUSE1_ID}    ${wh1_id}
    ${rack1_data}=      Generate Rack Data    ${TEST_WAREHOUSE1_ID}
    ${rack1_id}    ${rack1_response}=    Create Rack    ${rack1_data}
    Set Global Variable  ${TEST_RACK1_ID}    ${rack1_id}
    Log                 Setup Warehouse 1: ${TEST_WAREHOUSE1_ID}, Rack: ${TEST_RACK1_ID}

    ${wh2_data}=        Generate Warehouse Data    WH2
    ${wh2_id}    ${wh2_response}=    Create Warehouse    ${wh2_data}
    Set Global Variable  ${TEST_WAREHOUSE2_ID}    ${wh2_id}
    ${rack2_data}=      Generate Rack Data    ${TEST_WAREHOUSE2_ID}
    ${rack2_id}    ${rack2_response}=    Create Rack    ${rack2_data}
    Set Global Variable  ${TEST_RACK2_ID}    ${rack2_id}
    Log                 Setup Warehouse 2: ${TEST_WAREHOUSE2_ID}, Rack: ${TEST_RACK2_ID}

    # Positive - Create Master Products
    ${master1_data}=    Generate Master Product Data    ${TEST_WAREHOUSE1_ID}
    ${status_m1}    ${master1_response}=    Create Master Product    ${master1_data}
    Should Be Equal As Integers    ${status_m1}    201
    Set Global Variable  ${TEST_MASTER_ID1}    ${master1_response}[id]
    Log                 Created Master Product 1: ${TEST_MASTER_ID1}

    ${master2_data}=    Generate Master Product Data    ${TEST_WAREHOUSE2_ID}
    ${status_m2}    ${master2_response}=    Create Master Product    ${master2_data}
    Should Be Equal As Integers    ${status_m2}    201
    Set Global Variable  ${TEST_MASTER_ID2}    ${master2_response}[id]
    Log                 Created Master Product 2: ${TEST_MASTER_ID2}

    # Positive - Create Products
    ${prod1_data}=      Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}
    ${status_p1}    ${prod1_response}=    Create Product    ${prod1_data}
    Should Be Equal As Integers    ${status_p1}    201
    Set Global Variable  ${TEST_PRODUCT_ID1}    ${prod1_response}[id]
    Log                 Created Product 1: ${TEST_PRODUCT_ID1}

    ${prod2_data}=      Generate Product Data    ${TEST_WAREHOUSE2_ID}    ${TEST_MASTER_ID2}    ${TEST_RACK2_ID}
    ${status_p2}    ${prod2_response}=    Create Product    ${prod2_data}
    Should Be Equal As Integers    ${status_p2}    201
    Set Global Variable  ${TEST_PRODUCT_ID2}    ${prod2_response}[id]
    Log                 Created Product 2: ${TEST_PRODUCT_ID2}

    # Negative - Duplicate Barcode
    ${dup_data}=        Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    barcode=${prod1_data}[barCode]
    ${status_p3}    ${prod3_response}=    Create Product    ${dup_data}
    Should Be Equal As Integers    ${status_p3}    400
    Should Contain    ${prod3_response}[message]    barcode    ignore_case=True
    Log                 Prevented duplicate barcode creation

    # Positive - Scan Products
    ${status_scan1}    ${scan1_response}=    Scan Product    ${TEST_WAREHOUSE1_ID}    ["${prod1_data}[productCode]"]    ["${prod1_data}[barCode]"]    RACK-${TEST_RACK1_ID}
    Should Be Equal As Integers    ${status_scan1}    201
    Log                 Scanned Product 1 successfully

    # Negative - Invalid Barcode in Scan
    ${status_scan2}    ${scan2_response}=    Scan Product    ${TEST_WAREHOUSE1_ID}    ["${prod1_data}[productCode]"]    ["INVALID-BARCODE"]    RACK-${TEST_RACK1_ID}
    Should Be Equal As Integers    ${status_scan2}    400
    Should Contain    ${scan2_response}[message]    barcode    ignore_case=True
    Log                 Prevented scan with invalid barcode

    # Edge Case - Missing Required Scan Field (rackCode)
    ${scan_no_rack}=    Create Dictionary    warehouseId=${TEST_WAREHOUSE1_ID}    productCodes=["${prod1_data}[productCode]"]    barCodes=["${prod1_data}[barCode]"]    type=STORING
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /products/scan    json=${scan_no_rack}    headers=${headers}    expected_status=400
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    rackCode    ignore_case=True
    Log                 Prevented scan without rackCode

    # Positive - Recommend Products
    ${status_rec1}    ${rec1_response}=    Recommend Products    ${TEST_MASTER_ID1}    500    ${TEST_WAREHOUSE1_ID}
    Should Be Equal As Integers    ${status_rec1}    200
    Log                 Recommended products for Master ${TEST_MASTER_ID1}

    # Edge Case - Recommend Zero Quantity
    ${status_rec2}    ${rec2_response}=    Recommend Products    ${TEST_MASTER_ID1}    0    ${TEST_WAREHOUSE1_ID}
    Should Be Equal As Integers    ${status_rec2}    200    # Assuming API allows zero as valid
    Log                 Recommended with zero quantity

    # Positive - Split Product
    ${status_split1}    ${split1_response}=    Split Product    ${TEST_PRODUCT_ID1}    400
    Should Be Equal As Integers    ${status_split1}    201
    Set Global Variable  ${TEST_SPLIT_ID}    ${split1_response}[id]
    Log                 Split Product 1 into ${TEST_SPLIT_ID} with 400 units

    # Edge Case - Split to Max Capacity
    ${status_split2}    ${split2_response}=    Split Product    ${TEST_PRODUCT_ID2}    ${MAX_CAPACITY}
    Should Be Equal As Integers    ${status_split2}    400    # Assuming exceeds rack capacity
    Should Contain    ${split2_response}[message]    quantity    ignore_case=True
    Log                 Prevented split exceeding rack capacity

    # Positive - Concurrent Status Update
    ${status_upd1}    ${upd1_response}=    Update Multiple Products    [${TEST_PRODUCT_ID1}, ${TEST_SPLIT_ID}]    STORED    ${TEST_RACK1_ID}
    Should Be Equal As Integers    ${status_upd1}    201
    Log                 Updated Product 1 and Split Product to STORED status

    # Negative - Invalid Status
    ${status_upd2}    ${upd2_response}=    Update Multiple Products    [${TEST_PRODUCT_ID1}]    INVALID_STATUS    ${TEST_RACK1_ID}
    Should Be Equal As Integers    ${status_upd2}    400
    Should Contain    ${upd2_response}[message]    status    ignore_case=True
    Log                 Prevented update with invalid status

    # Validate Inventory Across Warehouses
    ${status_inv1}    ${inv1}=    Get Inventory    ${TEST_WAREHOUSE1_ID}
    Should Be Equal As Integers    ${status_inv1}    200
    Validate Inventory    ${inv1}    ${TEST_PRODUCT_ID1}    600
    Validate Inventory    ${inv1}    ${TEST_SPLIT_ID}    400
    Log                 Validated Warehouse 1 inventory

    ${status_inv2}    ${inv2}=    Get Inventory    ${TEST_WAREHOUSE2_ID}
    Should Be Equal As Integers    ${status_inv2}    200
    Validate Inventory    ${inv2}    ${TEST_PRODUCT_ID2}    1000
    Log                 Validated Warehouse 2 inventory

    # Cleanup
    Delete Product    ${TEST_PRODUCT_ID1}
    Delete Product    ${TEST_SPLIT_ID}
    Delete Product    ${TEST_PRODUCT_ID2}
    Delete MasterProduct    ${TEST_MASTER_ID1}
    Delete MasterProduct    ${TEST_MASTER_ID2}
    Delete Rack    ${TEST_RACK1_ID}
    Delete Rack    ${TEST_RACK2_ID}
    Delete Warehouse    ${TEST_WAREHOUSE1_ID}
    Delete Warehouse    ${TEST_WAREHOUSE2_ID}
    Log                 Cleaned up all test resources