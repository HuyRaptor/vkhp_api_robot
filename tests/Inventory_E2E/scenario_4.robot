*** Settings ***
Documentation     End-to-End Test Suite for Inventory Management with Stock Transfer
...               Tests product allocation, stock transfer between warehouses, and inventory validation
...               Includes positive, negative, missing parameters, and edge case validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn

*** Variables ***
${BASE_URL}             https://api.vkho.net
${MANAGER_USERNAME}     huynh22.manager
${MANAGER_PASSWORD}     Snowfox1991
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_WAREHOUSE1_ID}   ${EMPTY}
${TEST_WAREHOUSE2_ID}   ${EMPTY}
${TEST_RACK1_ID}        ${EMPTY}
${TEST_RACK2_ID}        ${EMPTY}
${TEST_MASTER_ID1}      ${EMPTY}
${TEST_MASTER_ID2}      ${EMPTY}
${TEST_PRODUCT_ID1}     ${EMPTY}
${TEST_PRODUCT_ID2}     ${EMPTY}
${TEST_TRANSFER_ID}     ${EMPTY}
${MAX_QUANTITY}         10000   # Maximum product/rack capacity
${MIN_QUANTITY}         1      # Minimum product quantity
${CURRENT_DATE}         2025-04-02T00:00:00Z    # Fixed date for testing

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
    ...                 address=789 Transfer Rd ${name_suffix}
    ...                 acreage=7000
    RETURN            ${warehouse_data}

Generate Rack Data
    [Arguments]         ${warehouse_id}    ${capacity}=${MAX_QUANTITY}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Master Product Data
    [Arguments]         ${warehouse_id}    ${name}=${NONE}    ${barcode}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${master_data}=     Create Dictionary
    ...                 name=${name if name is not NONE else "Master Transfer ${timestamp}"}
    ...                 capacity=600
    ...                 method=FIFO
    ...                 stogareTime=45
    ...                 image=https://example.com/transfer-master.jpg
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryId=1
    ...                 supplierIds=[1]
    ...                 purchasePrice=30.00
    ...                 salePrice=60.00
    ...                 retailPrice=70.00
    ...                 barCode=${barcode if barcode is not NONE else "BAR-MT${timestamp}"}
    ...                 VAT=10
    ...                 DVT=unit
    ...                 packing=box
    ...                 length=20
    ...                 width=20
    ...                 height=20
    ...                 itemCode=ITEM-T${timestamp}
    ...                 description=Master product for stock transfer
    ...                 isActive=${TRUE}
    ...                 discount=0
    ...                 isResources=${FALSE}
    ...                 availableQuantity=3000
    RETURN            ${master_data}

Generate Product Data
    [Arguments]         ${warehouse_id}    ${master_id}    ${rack_id}    ${quantity}=2000    ${barcode}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Transfer Product ${timestamp}
    ...                 totalQuantity=${quantity}
    ...                 expectedQuantity=${quantity}
    ...                 importDate=${CURRENT_DATE}
    ...                 cost=30.00
    ...                 salePrice=60.00
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2025-12-31T00:00:00Z
    ...                 productCode=TRANS-${timestamp}
    ...                 idRackReallocate=${rack_id}
    ...                 imageProduct=https://example.com/transfer-product.jpg
    ...                 imageQRCode=https://example.com/qr-transfer.jpg
    ...                 imageBarcode=https://example.com/barcode-transfer.jpg
    ...                 blockId=1
    ...                 supplierId=1
    ...                 productCategoryId=1
    ...                 rackId=${rack_id}
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=1
    ...                 packageId=1
    ...                 masterProductId=${master_id}
    ...                 note=Product for stock transfer
    ...                 barCode=${barcode if barcode is not NONE else "BAR-PT${timestamp}"}
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

Add Product To Rack
    [Arguments]         ${rack_id}    ${product_ids}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${rack_data}=       Create Dictionary    rackId=${rack_id}    productIds=${product_ids}
    ${response}=        POST On Session    vkho    /products/add/rack    json=${rack_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Transfer Stock
    [Documentation]     Transfer stock by splitting and updating warehouse/rack
    [Arguments]         ${product_id}    ${quantity}    ${new_warehouse_id}    ${new_rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${split_data}=      Create Dictionary    id=${product_id}    quantity=${quantity}
    ${split_response}=  POST On Session    vkho    /products/split    json=${split_data}    headers=${headers}    expected_status=201
    ${split_json}=      Evaluate         json.loads('''${split_response.text}''')    json
    ${new_product_id}=  Set Variable    ${split_json}[id]
    
    ${update_data}=     Create Dictionary
    ...                 id=${new_product_id}
    ...                 warehouseId=${new_warehouse_id}
    ...                 rackId=${new_rack_id}
    ...                 idRackReallocate=${new_rack_id}
    ...                 status=TRANSFERRED
    ...                 note=Transferred to new warehouse
    ${update_response}= POST On Session    vkho    /products/update    json=${update_data}    headers=${headers}    expected_status=any
    ${update_json}=     Evaluate         json.loads('''${update_response.text}''')    json
    RETURN            ${update_response.status_code}    ${update_json}    ${new_product_id}

Get Inventory
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session    vkho    /products/get-inventory    params=warehouseId=${warehouse_id}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Validate Inventory
    [Arguments]         ${inventory}    ${product_id}    ${expected_quantity}
    ${found}=           Set Variable    ${FALSE}
    FOR    ${item}    IN    @{inventory}
        ${item_id}=     Evaluate    str(${item}[id]) if 'id' in ${item} else None
        IF    "${item_id}" == "${product_id}"
            ${actual_quantity}=    Set Variable    ${item}[totalQuantity]
            Should Be Equal As Integers    ${actual_quantity}    ${expected_quantity}
            ...                            Mismatch: ${actual_quantity} vs ${expected_quantity} for ${product_id}
            ${found}=       Set Variable    ${TRUE}
            BREAK
        END
    END
    Should Be True    ${found}    Product ${product_id} not found in inventory

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

*** Test Cases ***
01 - Inventory Management with Stock Transfer Between Warehouses
    [Documentation]     End-to-end test for inventory with stock transfer and validation
    [Tags]              inventory    products    master-products    transfer    validation

    Setup Manager Session
    Log                 Manager session established

    # Setup Warehouses and Racks
    ${wh1_data}=        Generate Warehouse Data    Source
    ${wh1_id}    ${wh1_response}=    Create Warehouse    ${wh1_data}
    Set Global Variable  ${TEST_WAREHOUSE1_ID}    ${wh1_id}
    ${rack1_data}=      Generate Rack Data    ${TEST_WAREHOUSE1_ID}
    ${rack1_id}    ${rack1_response}=    Create Rack    ${rack1_data}
    Set Global Variable  ${TEST_RACK1_ID}    ${rack1_id}
    Log                 Created Source Warehouse: ${TEST_WAREHOUSE1_ID}, Rack: ${TEST_RACK1_ID}

    ${wh2_data}=        Generate Warehouse Data    Destination
    ${wh2_id}    ${wh2_response}=    Create Warehouse    ${wh2_data}
    Set Global Variable  ${TEST_WAREHOUSE2_ID}    ${wh2_id}
    ${rack2_data}=      Generate Rack Data    ${TEST_WAREHOUSE2_ID}
    ${rack2_id}    ${rack2_response}=    Create Rack    ${rack2_data}
    Set Global Variable  ${TEST_RACK2_ID}    ${rack2_id}
    Log                 Created Destination Warehouse: ${TEST_WAREHOUSE2_ID}, Rack: ${TEST_RACK2_ID}

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
    ${prod1_data}=      Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    2500
    ${status_p1}    ${prod1_response}=    Create Product    ${prod1_data}
    Should Be Equal As Integers    ${status_p1}    201
    Set Global Variable  ${TEST_PRODUCT_ID1}    ${prod1_response}[id]
    Log                 Created Product 1: ${TEST_PRODUCT_ID1}

    ${prod2_data}=      Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    1500
    ${status_p2}    ${prod2_response}=    Create Product    ${prod2_data}
    Should Be Equal As Integers    ${status_p2}    201
    Set Global Variable  ${TEST_PRODUCT_ID2}    ${prod2_response}[id]
    Log                 Created Product 2: ${TEST_PRODUCT_ID2}

    # Negative - Duplicate Product Code
    ${dup_data}=        Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}
    Set To Dictionary   ${dup_data}    productCode=${prod1_data}[productCode]
    ${status_p3}    ${prod3_response}=    Create Product    ${dup_data}
    Should Be Equal As Integers    ${status_p3}    400
    Should Contain    ${prod3_response}[message]    productCode    ignore_case=True
    Log                 Prevented creation with duplicate productCode

    # Missing Parameter - No rackId
    ${no_rack_data}=    Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}
    Remove From Dictionary    ${no_rack_data}    rackId
    ${status_p4}    ${prod4_response}=    Create Product    ${no_rack_data}
    Should Be Equal As Integers    ${status_p4}    400
    Should Contain    ${prod4_response}[message]    rackId    ignore_case=True
    Log                 Prevented creation without rackId

    # Positive - Assign Products to Rack
    ${status_rack1}    ${rack1_response}=    Add Product To Rack    ${TEST_RACK1_ID}    [${TEST_PRODUCT_ID1}, ${TEST_PRODUCT_ID2}]
    Should Be Equal As Integers    ${status_rack1}    201
    Log                 Assigned Products to Rack ${TEST_RACK1_ID}

    # Positive - Transfer Stock
    ${status_t1}    ${t1_response}    ${transfer_id}=    Transfer Stock    ${TEST_PRODUCT_ID1}    1000    ${TEST_WAREHOUSE2_ID}    ${TEST_RACK2_ID}
    Should Be Equal As Integers    ${status_t1}    201
    Set Global Variable  ${TEST_TRANSFER_ID}    ${transfer_id}
    Log                 Transferred 1000 units from Product 1 to ${TEST_TRANSFER_ID} in Warehouse 2

    # Negative - Transfer to Invalid Warehouse
    ${status_t2}    ${t2_response}    ${dummy_id}=    Transfer Stock    ${TEST_PRODUCT_ID2}    500    9999    ${TEST_RACK2_ID}
    Should Be Equal As Integers    ${status_t2}    400
    Should Contain    ${t2_response}[message]    warehouseId    ignore_case=True
    Log                 Prevented transfer to invalid warehouse

    # Edge Case - Transfer Maximum Quantity
    ${status_t3}    ${t3_response}    ${max_transfer_id}=    Transfer Stock    ${TEST_PRODUCT_ID2}    ${MAX_QUANTITY}    ${TEST_WAREHOUSE2_ID}    ${TEST_RACK2_ID}
    Should Be Equal As Integers    ${status_t3}    400    # Assuming exceeds remaining quantity or rack capacity
    Should Contain    ${t3_response}[message]    quantity    ignore_case=True
    Log                 Prevented transfer exceeding available quantity

    # Edge Case - Transfer Minimum Quantity
    ${status_t4}    ${t4_response}    ${min_transfer_id}=    Transfer Stock    ${TEST_PRODUCT_ID2}    ${MIN_QUANTITY}    ${TEST_WAREHOUSE2_ID}    ${TEST_RACK2_ID}
    Should Be Equal As Integers    ${status_t4}    201
    Log                 Transferred minimum quantity ${MIN_QUANTITY} from Product 2

    # Missing Parameter - Transfer without Quantity
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${no_qty_data}=     Create Dictionary    id=${TEST_PRODUCT_ID1}
    ${response}=        POST On Session    vkho    /products/split    json=${no_qty_data}    headers=${headers}    expected_status=400
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    quantity    ignore_case=True
    Log                 Prevented transfer without quantity

    # Positive - Validate Inventory
    ${status_inv1}    ${inv1}=    Get Inventory    ${TEST_WAREHOUSE1_ID}
    Should Be Equal As Integers    ${status_inv1}    200
    Validate Inventory    ${inv1}    ${TEST_PRODUCT_ID1}    1500    # 2500 - 1000 transferred
    Validate Inventory    ${inv1}    ${TEST_PRODUCT_ID2}    1499    # 1500 - 1 transferred
    Log                 Validated Source Warehouse inventory

    ${status_inv2}    ${inv2}=    Get Inventory    ${TEST_WAREHOUSE2_ID}
    Should Be Equal As Integers    ${status_inv2}    200
    Validate Inventory    ${inv2}    ${TEST_TRANSFER_ID}    1000
    Validate Inventory    ${inv2}    ${min_transfer_id}    ${MIN_QUANTITY}
    Log                 Validated Destination Warehouse inventory

    # Negative - Unauthorized Transfer (No Token)
    ${no_auth_headers}=    Create Dictionary    Content-Type=application/json
    ${split_data}=         Create Dictionary    id=${TEST_PRODUCT_ID1}    quantity=500
    ${response}=           POST On Session    vkho    /products/split    json=${split_data}    headers=${no_auth_headers}    expected_status=401
    ${json}=               Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    authorization    ignore_case=True
    Log                 Prevented unauthorized transfer

    # Edge Case - Transfer Zero Quantity
    ${status_t5}    ${t5_response}    ${zero_transfer_id}=    Transfer Stock    ${TEST_PRODUCT_ID1}    0    ${TEST_WAREHOUSE2_ID}    ${TEST_RACK2_ID}
    Should Be Equal As Integers    ${status_t5}    400    # Assuming API rejects zero
    Should Contain    ${t5_response}[message]    quantity    ignore_case=True
    Log                 Prevented transfer of zero quantity

    # Cleanup
    Delete Product    ${TEST_PRODUCT_ID1}
    Delete Product    ${TEST_PRODUCT_ID2}
    Delete Product    ${TEST_TRANSFER_ID}
    Delete Product    ${min_transfer_id}
    Delete MasterProduct    ${TEST_MASTER_ID1}
    Delete MasterProduct    ${TEST_MASTER_ID2}
    Delete Rack    ${TEST_RACK1_ID}
    Delete Rack    ${TEST_RACK2_ID}
    Delete Warehouse    ${TEST_WAREHOUSE1_ID}
    Delete Warehouse    ${TEST_WAREHOUSE2_ID}
    Log                 Cleaned up all test resources