*** Settings ***
Documentation     End-to-End Test Suite for Inventory Management with Batch Processing and Stock Auditing
...               Tests multi-product batch operations, supplier integration, and inventory auditing
...               Includes positive, negative, missing parameters, and edge case validations
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
    [Arguments]         ${name_suffix}=${EMPTY}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Warehouse ${name_suffix} ${timestamp}
    ...                 address=101 Batch St ${name_suffix}
    ...                 acreage=8000
    RETURN            ${warehouse_data}

Generate Rack Data
    [Arguments]         ${warehouse_id}    ${capacity}=${MAX_QUANTITY}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Supplier Data
    [Arguments]         ${name_suffix}=${EMPTY}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_data}=   Create Dictionary
    ...                 name=Supplier ${name_suffix} ${timestamp}
    ...                 phone=123-456-7890
    ...                 address=202 Supplier Rd ${name_suffix}
    ...                 email=supplier${timestamp}@example.com
    ...                 supplierCode=SUP-${timestamp}
    RETURN            ${supplier_data}

Generate Master Product Data
    [Arguments]         ${warehouse_id}    ${supplier_ids}    ${name}=${NONE}    ${barcode}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${master_data}=     Create Dictionary
    ...                 name=${name if name is not NONE else "Master Batch ${timestamp}"}
    ...                 capacity=1000
    ...                 method=FIFO
    ...                 stogareTime=60
    ...                 image=https://example.com/batch-master.jpg
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryId=1
    ...                 supplierIds=${supplier_ids}
    ...                 purchasePrice=40.00
    ...                 salePrice=80.00
    ...                 retailPrice=90.00
    ...                 barCode=${barcode if barcode is not NONE else "BAR-MB${timestamp}"}
    ...                 VAT=10
    ...                 DVT=unit
    ...                 packing=box
    ...                 length=25
    ...                 width=25
    ...                 height=25
    ...                 itemCode=ITEM-B${timestamp}
    ...                 description=Master product for batch processing
    ...                 isActive=${TRUE}
    ...                 discount=0
    ...                 isResources=${FALSE}
    ...                 availableQuantity=5000
    RETURN            ${master_data}

Generate Product Data
    [Arguments]         ${warehouse_id}    ${master_id}    ${rack_id}    ${supplier_id}    ${quantity}=1000    ${index}=0
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Batch Product ${timestamp}-${index}
    ...                 totalQuantity=${quantity}
    ...                 expectedQuantity=${quantity}
    ...                 importDate=${CURRENT_DATE}
    ...                 cost=40.00
    ...                 salePrice=80.00
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2025-12-31T00:00:00Z
    ...                 productCode=BATCH-${timestamp}-${index}
    ...                 idRackReallocate=${rack_id}
    ...                 imageProduct=https://example.com/batch-product-${index}.jpg
    ...                 imageQRCode=https://example.com/qr-batch-${index}.jpg
    ...                 imageBarcode=https://example.com/barcode-batch-${index}.jpg
    ...                 blockId=1
    ...                 supplierId=${supplier_id}
    ...                 productCategoryId=1
    ...                 rackId=${rack_id}
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=1
    ...                 packageId=1
    ...                 masterProductId=${master_id}
    ...                 note=Batch product ${index}
    ...                 barCode=BAR-PB${timestamp}-${index}
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

Create Supplier
    [Arguments]         ${supplier_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /suppliers/create    json=${supplier_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Master Product
    [Arguments]         ${master_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /master-products/create    json=${master_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Create Product Batch
    [Documentation]     Create a batch of products
    [Arguments]         ${warehouse_id}    ${master_id}    ${rack_id}    ${supplier_id}    ${batch_size}=10
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${product_ids}=     Create List
    FOR    ${i}    IN RANGE    ${batch_size}
        ${product_data}=    Generate Product Data    ${warehouse_id}    ${master_id}    ${rack_id}    ${supplier_id}    1000    ${i}
        ${response}=        POST On Session    vkho    /products/create    json=${product_data}    headers=${headers}    expected_status=any
        ${json}=            Evaluate         json.loads('''${response.text}''')    json
        Should Be Equal As Integers    ${response.status_code}    201
        Append To List    ${product_ids}    ${json}[id]
    END
    RETURN            ${product_ids}

Add Product To Rack
    [Arguments]         ${rack_id}    ${product_ids}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${rack_data}=       Create Dictionary    rackId=${rack_id}    productIds=${product_ids}
    ${response}=        POST On Session    vkho    /products/add/rack    json=${rack_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Update Product Batch
    [Documentation]     Update a batch of products with new quantities and statuses
    [Arguments]         ${product_ids}    ${quantity}    ${status}    ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${updates}=         Create List
    FOR    ${product_id}    IN    @{product_ids}
        ${update_data}=    Create Dictionary
        ...                 id=${product_id}
        ...                 totalQuantity=${quantity}
        ...                 status=${status}
        ...                 rackId=${rack_id}
        ...                 note=Batch update
        Append To List    ${updates}    ${update_data}
    END
    ${response}=        POST On Session    vkho    /products/updates    json=${updates}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Get Inventory
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session    vkho    /products/get-inventory    params=warehouseId=${warehouse_id}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Audit Inventory
    [Documentation]     Audit inventory by checking total quantities and supplier consistency
    [Arguments]         ${warehouse_id}    ${product_ids}    ${expected_quantity}    ${supplier_id}
    ${status}    ${inventory}=    Get Inventory    ${warehouse_id}
    Should Be Equal As Integers    ${status}    200
    ${matched_count}=    Set Variable    0
    FOR    ${item}    IN    @{inventory}
        ${item_id}=     Evaluate    str(${item}[id]) if 'id' in ${item} else None
        IF    "${item_id}" in ${product_ids}
            Should Be Equal As Integers    ${item}[totalQuantity]    ${expected_quantity}
            ...                            Mismatch: ${item}[totalQuantity] vs ${expected_quantity} for ${item_id}
            Should Be Equal As Integers    ${item}[supplierId]    ${supplier_id}
            ...                            Supplier mismatch: ${item}[supplierId] vs ${supplier_id} for ${item_id}
            ${matched_count}=    Evaluate    ${matched_count} + 1
        END
    END
    Should Be Equal As Integers    ${matched_count}    ${${product_ids}.__len__()}
    ...                            Audit failed: ${matched_count} products matched vs ${${product_ids}.__len__()} expected

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

Delete Supplier
    [Arguments]         ${supplier_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /suppliers/delete/${supplier_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

*** Test Cases ***
01 - Inventory Management with Batch Processing and Stock Auditing
    [Documentation]     End-to-end test for inventory with batch processing, supplier integration, and auditing
    [Tags]              inventory    products    master-products    suppliers    batch    audit

    Setup Manager Session
    Log                 Manager session established

    # Setup Warehouses and Racks
    ${wh1_data}=        Generate Warehouse Data    Primary
    ${wh1_id}    ${wh1_response}=    Create Warehouse    ${wh1_data}
    Set Global Variable  ${TEST_WAREHOUSE1_ID}    ${wh1_id}
    ${rack1_data}=      Generate Rack Data    ${TEST_WAREHOUSE1_ID}
    ${rack1_id}    ${rack1_response}=    Create Rack    ${rack1_data}
    Set Global Variable  ${TEST_RACK1_ID}    ${rack1_id}
    Log                 Created Primary Warehouse: ${TEST_WAREHOUSE1_ID}, Rack: ${TEST_RACK1_ID}

    ${wh2_data}=        Generate Warehouse Data    Secondary
    ${wh2_id}    ${wh2_response}=    Create Warehouse    ${wh2_data}
    Set Global Variable  ${TEST_WAREHOUSE2_ID}    ${wh2_id}
    ${rack2_data}=      Generate Rack Data    ${TEST_WAREHOUSE2_ID}
    ${rack2_id}    ${rack2_response}=    Create Rack    ${rack2_data}
    Set Global Variable  ${TEST_RACK2_ID}    ${rack2_id}
    Log                 Created Secondary Warehouse: ${TEST_WAREHOUSE2_ID}, Rack: ${TEST_RACK2_ID}

    # Setup Suppliers
    ${sup1_data}=       Generate Supplier Data    A
    ${sup1_id}    ${sup1_response}=    Create Supplier    ${sup1_data}
    Set Global Variable  ${TEST_SUPPLIER_ID1}    ${sup1_id}
    ${sup2_data}=       Generate Supplier Data    B
    ${sup2_id}    ${sup2_response}=    Create Supplier    ${sup2_data}
    Set Global Variable  ${TEST_SUPPLIER_ID2}    ${sup2_id}
    Log                 Created Suppliers: ${TEST_SUPPLIER_ID1}, ${TEST_SUPPLIER_ID2}

    # Positive - Create Master Products with Suppliers
    ${master1_data}=    Generate Master Product Data    ${TEST_WAREHOUSE1_ID}    [${TEST_SUPPLIER_ID1}]
    ${status_m1}    ${master1_response}=    Create Master Product    ${master1_data}
    Should Be Equal As Integers    ${status_m1}    201
    Set Global Variable  ${TEST_MASTER_ID1}    ${master1_response}[id]
    Log                 Created Master Product 1: ${TEST_MASTER_ID1}

    ${master2_data}=    Generate Master Product Data    ${TEST_WAREHOUSE2_ID}    [${TEST_SUPPLIER_ID2}]
    ${status_m2}    ${master2_response}=    Create Master Product    ${master2_data}
    Should Be Equal As Integers    ${status_m2}    201
    Set Global Variable  ${TEST_MASTER_ID2}    ${master2_response}[id]
    Log                 Created Master Product 2: ${TEST_MASTER_ID2}

    # Positive - Create Product Batch
    ${batch_size}=      Set Variable    5
    ${product_ids1}=    Create Product Batch    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID1}    ${batch_size}
    Set Global Variable  ${TEST_PRODUCT_IDS}    ${product_ids1}
    Log                 Created batch of ${batch_size} products: ${TEST_PRODUCT_IDS}

    # Negative - Invalid Supplier ID in Product Creation
    ${invalid_sup_data}=    Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    9999
    ${status_p1}    ${prod1_response}=    Create Product    ${invalid_sup_data}
    Should Be Equal As Integers    ${status_p1}    400
    Should Contain    ${prod1_response}[message]    supplierId    ignore_case=True
    Log                 Prevented creation with invalid supplierId

    # Missing Parameter - No supplierId in Product
    ${no_sup_data}=    Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID1}
    Remove From Dictionary    ${no_sup_data}    supplierId
    ${status_p2}    ${prod2_response}=    Create Product    ${no_sup_data}
    Should Be Equal As Integers    ${status_p2}    400
    Should Contain    ${prod2_response}[message]    supplierId    ignore_case=True
    Log                 Prevented creation without supplierId

    # Positive - Assign Batch to Rack
    ${status_rack1}    ${rack1_response}=    Add Product To Rack    ${TEST_RACK1_ID}    ${TEST_PRODUCT_IDS}
    Should Be Equal As Integers    ${status_rack1}    201
    Log                 Assigned batch to Rack ${TEST_RACK1_ID}

    # Edge Case - Assign Batch Exceeding Rack Capacity
    ${large_batch}=    Create Product Batch    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID1}    ${MAX_BATCH_SIZE}
    ${status_rack2}    ${rack2_response}=    Add Product To Rack    ${TEST_RACK1_ID}    ${large_batch}
    Should Be Equal As Integers    ${status_rack2}    400    # Assuming capacity limit
    Should Contain    ${rack2_response}[message]    capacity    ignore_case=True
    Log                 Prevented assignment of oversized batch to Rack ${TEST_RACK1_ID}

    # Positive - Update Batch (Simulate Restocking)
    ${status_upd1}    ${upd1_response}=    Update Product Batch    ${TEST_PRODUCT_IDS}    1500    STOCKED    ${TEST_RACK1_ID}
    Should Be Equal As Integers    ${status_upd1}    201
    Log                 Updated batch to 1500 units, status STOCKED

    # Negative - Update with Invalid Status
    ${status_upd2}    ${upd2_response}=    Update Product Batch    ${TEST_PRODUCT_IDS}    1200    INVALID_STATUS    ${TEST_RACK1_ID}
    Should Be Equal As Integers    ${status_upd2}    400
    Should Contain    ${upd2_response}[message]    status    ignore_case=True
    Log                 Prevented batch update with invalid status

    # Edge Case - Update to Minimum Quantity
    ${status_upd3}    ${upd3_response}=    Update Product Batch    ${TEST_PRODUCT_IDS}    ${MIN_QUANTITY}    STOCKED    ${TEST_RACK1_ID}
    Should Be Equal As Integers    ${status_upd3}    201
    Log                 Updated batch to minimum quantity ${MIN_QUANTITY}

    # Missing Parameter - Update without Quantity
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${no_qty_updates}=  Create List
    FOR    ${product_id}    IN    @{TEST_PRODUCT_IDS}
        ${update_data}=    Create Dictionary    id=${product_id}    status=STOCKED    rackId=${TEST_RACK1_ID}
        Append To List    ${no_qty_updates}    ${update_data}
    END
    ${response}=        POST On Session    vkho    /products/updates    json=${no_qty_updates}    headers=${headers}    expected_status=400
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    totalQuantity    ignore_case=True
    Log                 Prevented batch update without totalQuantity

    # Positive - Audit Inventory
    Audit Inventory    ${TEST_WAREHOUSE1_ID}    ${TEST_PRODUCT_IDS}    ${MIN_QUANTITY}    ${TEST_SUPPLIER_ID1}
    Log                 Audited Warehouse 1: quantities and supplier IDs match

    # Edge Case - Audit Empty Warehouse
    ${status_inv2}    ${inv2}=    Get Inventory    ${TEST_WAREHOUSE2_ID}
    Should Be Equal As Integers    ${status_inv2}    200
    Should Be Empty    ${inv2}    Empty warehouse audit failed
    Log                 Audited empty Warehouse 2 successfully

    # Negative - Unauthorized Batch Update
    ${no_auth_headers}=    Create Dictionary    Content-Type=application/json
    ${updates}=            Create List
    FOR    ${product_id}    IN    @{TEST_PRODUCT_IDS}
        ${update_data}=    Create Dictionary    id=${product_id}    totalQuantity=1000    status=STOCKED    rackId=${TEST_RACK1_ID}
        Append To List    ${updates}    ${update_data}
    END
    ${response}=           POST On Session    vkho    /products/updates    json=${updates}    headers=${no_auth_headers}    expected_status=401
    ${json}=               Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    authorization    ignore_case=True
    Log                 Prevented unauthorized batch update

    # Edge Case - Maximum Batch Size Creation
    ${max_batch}=    Create Product Batch    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID1}    ${MAX_BATCH_SIZE}
    ${status_rack3}    ${rack3_response}=    Add Product To Rack    ${TEST_RACK1_ID}    ${max_batch}
    Should Be Equal As Integers    ${status_rack3}    201    # Assuming within capacity
    Log                 Created and assigned maximum batch size ${MAX_BATCH_SIZE}

    # Cleanup
    FOR    ${product_id}    IN    @{TEST_PRODUCT_IDS}
        Delete Product    ${product_id}
    END
    FOR    ${product_id}    IN    @{large_batch}
        Delete Product    ${product_id}
    END
    FOR    ${product_id}    IN    @{max_batch}
        Delete Product    ${product_id}
    END
    Delete MasterProduct    ${TEST_MASTER_ID1}
    Delete MasterProduct    ${TEST_MASTER_ID2}
    Delete Rack    ${TEST_RACK1_ID}
    Delete Rack    ${TEST_RACK2_ID}
    Delete Warehouse    ${TEST_WAREHOUSE1_ID}
    Delete Warehouse    ${TEST_WAREHOUSE2_ID}
    Delete Supplier    ${TEST_SUPPLIER_ID1}
    Delete Supplier    ${TEST_SUPPLIER_ID2}
    Log                 Cleaned up all test resources