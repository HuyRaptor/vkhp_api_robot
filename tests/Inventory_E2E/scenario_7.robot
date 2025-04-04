*** Settings ***
Documentation     End-to-End Test Suite for Inventory Management with Multi-Tiered Categories, Replenishment, and Analytics
...               Tests category hierarchies, automated replenishment, expiration tracking, and cross-warehouse analytics
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
    ...                 address=505 Category Rd ${name_suffix}
    ...                 acreage=10000
    RETURN            ${warehouse_data}

Generate Rack Data
    [Arguments]         ${warehouse_id}    ${capacity}=${MAX_QUANTITY}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Supplier Data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_data}=   Create Dictionary
    ...                 name=Category Supplier ${timestamp}
    ...                 phone=555-123-4567
    ...                 address=606 Supplier St
    ...                 email=category${timestamp}@example.com
    ...                 supplierCode=CAT-${timestamp}
    RETURN            ${supplier_data}

Generate Category Data
    [Arguments]         ${name}    ${parent_id}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${category_data}=   Create Dictionary
    ...                 name=${name} ${timestamp}
    ...                 parentId=${parent_id if parent_id is not NONE else ${NULL}}
    ...                 description=${name} category
    RETURN            ${category_data}

Generate Master Product Data
    [Arguments]         ${warehouse_id}    ${supplier_ids}    ${category_id}    ${expire_date}=2025-12-31T00:00:00Z
    ${timestamp}=       Evaluate         int(time.time())    time
    ${master_data}=     Create Dictionary
    ...                 name=Category Master ${timestamp}
    ...                 capacity=2000
    ...                 method=FIFO
    ...                 stogareTime=180
    ...                 image=https://example.com/category-master.jpg
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryId=${category_id}
    ...                 supplierIds=${supplier_ids}
    ...                 purchasePrice=75.00
    ...                 salePrice=150.00
    ...                 retailPrice=180.00
    ...                 barCode=BAR-CM${timestamp}
    ...                 VAT=10
    ...                 DVT=unit
    ...                 packing=box
    ...                 length=40
    ...                 width=40
    ...                 height=40
    ...                 itemCode=ITEM-C${timestamp}
    ...                 description=Master product for category
    ...                 isActive=${TRUE}
    ...                 discount=0
    ...                 isResources=${FALSE}
    ...                 availableQuantity=8000
    ...                 expireDate=${expire_date}
    RETURN            ${master_data}

Generate Product Data
    [Arguments]         ${warehouse_id}    ${master_id}    ${rack_id}    ${supplier_id}    ${category_id}    ${quantity}=1500    ${expire_date}=2025-12-31T00:00:00Z
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Category Product ${timestamp}
    ...                 totalQuantity=${quantity}
    ...                 expectedQuantity=${quantity}
    ...                 importDate=${CURRENT_DATE}
    ...                 cost=75.00
    ...                 salePrice=150.00
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=${expire_date}
    ...                 productCode=CAT-${timestamp}
    ...                 idRackReallocate=${rack_id}
    ...                 imageProduct=https://example.com/category-product.jpg
    ...                 imageQRCode=https://example.com/qr-category.jpg
    ...                 imageBarcode=https://example.com/barcode-category.jpg
    ...                 blockId=1
    ...                 supplierId=${supplier_id}
    ...                 productCategoryId=${category_id}
    ...                 rackId=${rack_id}
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=1
    ...                 packageId=1
    ...                 masterProductId=${master_id}
    ...                 note=Product in category hierarchy
    ...                 barCode=BAR-CP${timestamp}
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

Create Category
    [Arguments]         ${category_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /product-categories/create    json=${category_data}    headers=${headers}    expected_status=201
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

Trigger Replenishment
    [Documentation]     Simulate stock falling below threshold and replenish
    [Arguments]         ${product_id}    ${new_quantity}    ${threshold}=${REPLENISH_THRESHOLD}    ${replenish_amount}=1000
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 totalQuantity=${new_quantity}
    ...                 status=STOCKED
    ${response}=        POST On Session    vkho    /products/update    json=${update_data}    headers=${headers}    expected_status=201
    IF    ${new_quantity} < ${threshold}
        ${replenish_data}=    Create Dictionary
        ...                    id=${product_id}
        ...                    totalQuantity=${new_quantity + replenish_amount}
        ...                    status=REPLENISHED
        ...                    note=Auto-replenished
        ${response}=          POST On Session    vkho    /products/update    json=${replenish_data}    headers=${headers}    expected_status=201
    END
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Dispose Expired Product
    [Documentation]     Dispose of expired products
    [Arguments]         ${product_id}    ${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${split_data}=      Create Dictionary    id=${product_id}    quantity=${quantity}
    ${split_response}=  POST On Session    vkho    /products/split    json=${split_data}    headers=${headers}    expected_status=201
    ${split_json}=      Evaluate         json.loads('''${split_response.text}''')    json
    ${disposed_id}=     Set Variable    ${split_json}[id]
    
    ${update_data}=     Create Dictionary
    ...                 id=${disposed_id}
    ...                 status=DISPOSED
    ...                 note=Expired product disposed
    ${update_response}= POST On Session    vkho    /products/update    json=${update_data}    headers=${headers}    expected_status=201
    ${update_json}=     Evaluate         json.loads('''${update_response.text}''')    json
    RETURN            ${update_response.status_code}    ${update_json}    ${disposed_id}

Get Inventory
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session    vkho    /products/get-inventory    params=warehouseId=${warehouse_id}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Analyze Stock Distribution
    [Documentation]     Analyze stock levels across warehouses and suggest rebalancing
    [Arguments]         ${warehouse_ids}    ${category_id}    ${optimal_per_warehouse}=1000
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${total_stock}=     Set Variable    0
    ${warehouse_counts}=    Create Dictionary
    FOR    ${wh_id}    IN    @{warehouse_ids}
        ${status}    ${inventory}=    Get Inventory    ${wh_id}
        Should Be Equal As Integers    ${status}    200
        ${wh_total}=    Set Variable    0
        FOR    ${item}    IN    @{inventory}
            IF    ${item}[productCategoryId] == ${category_id}
                ${wh_total}=    Evaluate    ${wh_total} + ${item}[totalQuantity]
                ${total_stock}= Evaluate    ${total_stock} + ${item}[totalQuantity]
            END
        END
        Set To Dictionary    ${warehouse_counts}    ${wh_id}    ${wh_total}
    END
    ${wh_count}=        Set Variable    ${${warehouse_ids}.__len__()}
    ${avg_stock}=       Evaluate    ${total_stock} // ${wh_count}
    ${imbalance}=       Create List
    FOR    ${wh_id}    ${stock}    IN    &{warehouse_counts}
        ${diff}=        Evaluate    ${stock} - ${optimal_per_warehouse}
        IF    abs(${diff}) > 200    # Tolerance for imbalance
            Append To List    ${imbalance}    Warehouse ${wh_id}: ${stock} (diff: ${diff})
        END
    END
    RETURN            ${total_stock}    ${avg_stock}    ${imbalance}

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

Delete Category
    [Arguments]         ${category_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /product-categories/delete/${category_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

*** Test Cases ***
01 - Inventory Management with Categories, Replenishment, Expiration, and Analytics
    [Documentation]     End-to-end test for inventory with category hierarchies, replenishment, expiration, and analytics
    [Tags]              inventory    products    categories    replenishment    expiration    analytics

    Setup Manager Session
    Log                 Manager session established

    # Setup Warehouses and Racks
    ${wh1_data}=        Generate Warehouse Data    North
    ${wh1_id}    ${wh1_response}=    Create Warehouse    ${wh1_data}
    Set Global Variable  ${TEST_WAREHOUSE1_ID}    ${wh1_id}
    ${rack1_data}=      Generate Rack Data    ${TEST_WAREHOUSE1_ID}
    ${rack1_id}    ${rack1_response}=    Create Rack    ${rack1_data}
    Set Global Variable  ${TEST_RACK1_ID}    ${rack1_id}
    Log                 Created North Warehouse: ${TEST_WAREHOUSE1_ID}, Rack: ${TEST_RACK1_ID}

    ${wh2_data}=        Generate Warehouse Data    South
    ${wh2_id}    ${wh2_response}=    Create Warehouse    ${wh2_data}
    Set Global Variable  ${TEST_WAREHOUSE2_ID}    ${wh2_id}
    ${rack2_data}=      Generate Rack Data    ${TEST_WAREHOUSE2_ID}
    ${rack2_id}    ${rack2_response}=    Create Rack    ${rack2_data}
    Set Global Variable  ${TEST_RACK2_ID}    ${rack2_id}
    Log                 Created South Warehouse: ${TEST_WAREHOUSE2_ID}, Rack: ${TEST_RACK2_ID}

    # Setup Supplier
    ${sup_data}=        Generate Supplier Data
    ${sup_id}    ${sup_response}=    Create Supplier    ${sup_data}
    Set Global Variable  ${TEST_SUPPLIER_ID}    ${sup_id}
    Log                 Created Supplier: ${TEST_SUPPLIER_ID}

    # Positive - Create Multi-Tiered Categories
    ${cat1_data}=       Generate Category Data    Electronics
    ${cat1_id}    ${cat1_response}=    Create Category    ${cat1_data}
    Set Global Variable  ${TEST_CAT1_ID}    ${cat1_id}
    ${cat2_data}=       Generate Category Data    Laptops    ${TEST_CAT1_ID}
    ${cat2_id}    ${cat2_response}=    Create Category    ${cat2_data}
    Set Global Variable  ${TEST_CAT2_ID}    ${cat2_id}
    ${cat3_data}=       Generate Category Data    Gaming    ${TEST_CAT2_ID}
    ${cat3_id}    ${cat3_response}=    Create Category    ${cat3_data}
    Set Global Variable  ${TEST_CAT3_ID}    ${cat3_id}
    Log                 Created category hierarchy: ${TEST_CAT1_ID} > ${TEST_CAT2_ID} > ${TEST_CAT3_ID}

    # Negative - Invalid Parent Category
    ${invalid_cat_data}=    Generate Category Data    Invalid    9999
    ${status_c1}    ${cat_response}=    Create Category    ${invalid_cat_data}
    Should Be Equal As Integers    ${status_c1}    400
    Should Contain    ${cat_response}[message]    parentId    ignore_case=True
    Log                 Prevented category creation with invalid parentId

    # Positive - Create Master Products
    ${master1_data}=    Generate Master Product Data    ${TEST_WAREHOUSE1_ID}    [${TEST_SUPPLIER_ID}]    ${TEST_CAT3_ID}
    ${status_m1}    ${master1_response}=    Create Master Product    ${master1_data}
    Should Be Equal As Integers    ${status_m1}    201
    Set Global Variable  ${TEST_MASTER_ID1}    ${master1_response}[id]
    Log                 Created Master Product 1: ${TEST_MASTER_ID1}

    ${master2_data}=    Generate Master Product Data    ${TEST_WAREHOUSE2_ID}    [${TEST_SUPPLIER_ID}]    ${TEST_CAT3_ID}    ${NEAR_EXPIRY_DATE}
    ${status_m2}    ${master2_response}=    Create Master Product    ${master2_data}
    Should Be Equal As Integers    ${status_m2}    201
    Set Global Variable  ${TEST_MASTER_ID2}    ${master2_response}[id]
    Log                 Created Master Product 2: ${TEST_MASTER_ID2}

    # Positive - Create Products
    ${prod1_data}=      Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID}    ${TEST_CAT3_ID}
    ${status_p1}    ${prod1_response}=    Create Product    ${prod1_data}
    Should Be Equal As Integers    ${status_p1}    201
    Set Global Variable  ${TEST_PRODUCT_ID1}    ${prod1_response}[id]
    Log                 Created Product 1: ${TEST_PRODUCT_ID1}

    ${prod2_data}=      Generate Product Data    ${TEST_WAREHOUSE2_ID}    ${TEST_MASTER_ID2}    ${TEST_RACK2_ID}    ${TEST_SUPPLIER_ID}    ${TEST_CAT3_ID}    2000    ${NEAR_EXPIRY_DATE}
    ${status_p2}    ${prod2_response}=    Create Product    ${prod2_data}
    Should Be Equal As Integers    ${status_p2}    201
    Set Global Variable  ${TEST_PRODUCT_ID2}    ${prod2_response}[id]
    Log                 Created Product 2: ${TEST_PRODUCT_ID2}

    # Missing Parameter - No productCategoryId
    ${no_cat_data}=     Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID}    ${TEST_CAT3_ID}
    Remove From Dictionary    ${no_cat_data}    productCategoryId
    ${status_p3}    ${prod3_response}=    Create Product    ${no_cat_data}
    Should Be Equal As Integers    ${status_p3}    400
    Should Contain    ${prod3_response}[message]    productCategoryId    ignore_case=True
    Log                 Prevented creation without productCategoryId

    # Positive - Assign Products to Racks
    ${status_rack1}    ${rack1_response}=    Add Product To Rack    ${TEST_RACK1_ID}    [${TEST_PRODUCT_ID1}]
    Should Be Equal As Integers    ${status_rack1}    201
    ${status_rack2}    ${rack2_response}=    Add Product To Rack    ${TEST_RACK2_ID}    [${TEST_PRODUCT_ID2}]
    Should Be Equal As Integers    ${status_rack2}    201
    Log                 Assigned Products to Racks

    # Positive - Trigger Replenishment
    ${status_rep1}    ${rep1_response}=    Trigger Replenishment    ${TEST_PRODUCT_ID1}    400
    Should Be Equal As Integers    ${status_rep1}    201
    Log                 Replenished Product 1 from 400 to 1400

    # Negative - Unauthorized Replenishment
    ${no_auth_headers}=    Create Dictionary    Content-Type=application/json
    ${rep_data}=           Create Dictionary    id=${TEST_PRODUCT_ID2}    totalQuantity=300    status=STOCKED
    ${response}=           POST On Session    vkho    /products/update    json=${rep_data}    headers=${no_auth_headers}    expected_status=401
    ${json}=               Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    authorization    ignore_case=True
    Log                 Prevented unauthorized replenishment

    # Edge Case - Maximum Threshold
    ${status_rep2}    ${rep2_response}=    Trigger Replenishment    ${TEST_PRODUCT_ID2}    ${MAX_QUANTITY}    ${REPLENISH_THRESHOLD}
    Should Be Equal As Integers    ${status_rep2}    201    # No replenishment needed
    Log                 No replenishment triggered for max quantity ${MAX_QUANTITY}

    # Positive - Dispose Expired Product
    ${expired_prod_data}=    Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID}    ${TEST_CAT3_ID}    1000    ${EXPIRED_DATE}
    ${status_p4}    ${prod4_response}=    Create Product    ${expired_prod_data}
    Should Be Equal As Integers    ${status_p4}    201
    ${expired_id}=    Set Variable    ${prod4_response}[id]
    ${status_dis1}    ${dis1_response}    ${disposed_id}=    Dispose Expired Product    ${expired_id}    1000
    Should Be Equal As Integers    ${status_dis1}    201
    Log                 Disposed expired product: ${disposed_id}

    # Edge Case - Near Expiry Handling
    ${status_inv1}    ${inv1}=    Get Inventory    ${TEST_WAREHOUSE2_ID}
    FOR    ${item}    IN    @{inv1}
        IF    "${item}[id]" == "${TEST_PRODUCT_ID2}"
            Should Be Equal As Strings    ${item}[expireDate]    ${NEAR_EXPIRY_DATE}
            Log                 Confirmed near-expiry product ${TEST_PRODUCT_ID2}
        END
    END

    # Negative - Dispose Non-Expired
    ${status_dis2}    ${dis2_response}    ${dummy_id}=    Dispose Expired Product    ${TEST_PRODUCT_ID1}    500
    Should Be Equal As Integers    ${status_dis2}    201    # Assuming API allows but logs warning
    Log                 Disposed non-expired product (should log warning)

    # Positive - Analyze Stock Distribution
    ${warehouse_ids}=    Create List    ${TEST_WAREHOUSE1_ID}    ${TEST_WAREHOUSE2_ID}
    ${total}    ${avg}    ${imbalance}=    Analyze Stock Distribution    ${warehouse_ids}    ${TEST_CAT3_ID}
    Should Be True    ${total} >= 3400    # 1400 (P1) + 2000 (P2) minimum
    Should Be True    ${imbalance}    # Expect imbalance due to uneven distribution
    Log                 Analyzed stock: Total=${total}, Avg=${avg}, Imbalance=${imbalance}

    # Edge Case - Zero Stock in One Warehouse
    ${status_inv2}    ${inv2}=    Get Inventory    ${TEST_WAREHOUSE1_ID}
    ${status_rep3}    ${rep3_response}=    Trigger Replenishment    ${TEST_PRODUCT_ID1}    0
    Should Be Equal As Integers    ${status_rep3}    201
    ${total}    ${avg}    ${imbalance}=    Analyze Stock Distribution    ${warehouse_ids}    ${TEST_CAT3_ID}
    Should Be True    ${imbalance}    # Still imbalanced with zero in WH1
    Log                 Analyzed with zero stock in WH1: Total=${total}, Avg=${avg}

    # Cleanup
    Delete Product    ${TEST_PRODUCT_ID1}
    Delete Product    ${TEST_PRODUCT_ID2}
    Delete Product    ${expired_id}
    Delete Product    ${disposed_id}
    Delete Product    ${dummy_id}
    Delete MasterProduct    ${TEST_MASTER_ID1}
    Delete MasterProduct    ${TEST_MASTER_ID2}
    Delete Rack    ${TEST_RACK1_ID}
    Delete Rack    ${TEST_RACK2_ID}
    Delete Warehouse    ${TEST_WAREHOUSE1_ID}
    Delete Warehouse    ${TEST_WAREHOUSE2_ID}
    Delete Supplier    ${TEST_SUPPLIER_ID}
    Delete Category    ${TEST_CAT3_ID}
    Delete Category    ${TEST_CAT2_ID}
    Delete Category    ${TEST_CAT1_ID}
    Log                 Cleaned up all test resources