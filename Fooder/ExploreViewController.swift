//
//  ExploreViewController.swift
//  Fooder
//
//  Created by Vladimir on 25.12.16.
//  Copyright © 2016 Vladimir Ageev. All rights reserved.
//

import UIKit
import Alamofire
import DZNEmptyDataSet

class ExploreViewController: UIViewController {

    @IBOutlet var foodTypeSegmentControl: UISegmentedControl!
    @IBOutlet var foodTypeScrollView: UIScrollView!
    @IBOutlet var searchButton: UIBarButtonItem!
    @IBOutlet var collectionView: UICollectionView!
    let searchBar = UISearchBar()
    var lastOffset: CGFloat = 0
    var loadingMore = false
    var noMoreResults = false
    var currentQuery = ""
    
    var recipes = [Recipe](){
        didSet{
            if loadingMore{
                updateCollectionView(old: oldValue)
                return
            }
            collectionView.reloadData()
        }
    }
    var model: ExploreModel!
    
    var prefetchedImagesForCells = [Int: UIImage]()

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.prefetchDataSource = self
        collectionView.emptyDataSetSource = self
        collectionView.emptyDataSetDelegate = self
        model = ExploreModel.sharedInstance
        model.delegate = self
        search()
        searchBar.delegate = self
        searchBar.showsCancelButton = true
        searchBar.searchBarStyle = .minimal
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let statusBarBlur = UIBlurEffect(style: .extraLight)
        let statusBarBlurView = UIVisualEffectView(effect: statusBarBlur)
        statusBarBlurView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 20)
        view.addSubview(statusBarBlurView)
        lastOffset = self.collectionView.contentOffset.y
        foodTypeScrollView.isHidden = self.navigationItem.titleView != searchBar
    }
    
    deinit {
        collectionView.emptyDataSetDelegate = nil
        collectionView.emptyDataSetSource = nil
    }
    
    @IBAction func searchButtonPressed(_ sender: Any) {
        self.navigationItem.titleView?.addSubview(searchBar)
        self.navigationItem.titleView = searchBar
        self.navigationItem.rightBarButtonItem = nil
        foodTypeScrollView.isHidden = false
        searchBar.becomeFirstResponder()
    }
    
    
    @IBAction func segmentControlValueChanged(_ sender: UISegmentedControl) {
        search()
        
        let selectedIndex = sender.selectedSegmentIndex
        let itemWidth = sender.widthForSegment(at: selectedIndex)
        let rightBorder = itemWidth * CGFloat(selectedIndex + 1)
        let leftBorder = itemWidth * CGFloat(selectedIndex)
        let half = foodTypeScrollView.frame.width/2
        
        if foodTypeScrollView.contentOffset.x + foodTypeScrollView.frame.width <= rightBorder{
            foodTypeScrollView.scrollRectToVisible( CGRect(x: leftBorder, y: foodTypeScrollView.contentOffset.y, width: half, height: foodTypeScrollView.frame.height), animated: true)
        }
        
        if foodTypeScrollView.contentOffset.x >= leftBorder{
            foodTypeScrollView.scrollRectToVisible( CGRect(x: rightBorder - half, y: foodTypeScrollView.contentOffset.y, width: half, height: foodTypeScrollView.frame.height), animated: true)
        }
        
        if !collectionView.visibleCells.isEmpty{
            collectionView.scrollToItem(at: IndexPath(row:0, section: 0), at: .top, animated: true)
        }
    }
    
    func search(offset: Int = 0, more: Bool = false){
        let foodType =   foodTypeSegmentControl.titleForSegment(at: foodTypeSegmentControl.selectedSegmentIndex)?.lowercased() ?? "all"
        let foodTypeEnum = FoodType(rawValue: foodType) ?? .all
        let query = currentQuery
        loadingMore = more
        if !more{
            prefetchedImagesForCells.removeAll()
        }
        model.searchRecipes(query: query, type: foodTypeEnum, offset:offset, more: more)
    }
}

//MARK: - Collection view delegare/data source
extension ExploreViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
     func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
     func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return recipes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MealCell",
                                                      for: indexPath)
        
        cell.sizeThatFits(CGSize(width: view.frame.width, height: cell.frame.height))
        
        if let cell =  cell as? ExploreRecipeCell{
            var prefetched = false
            if let prefetchedImage = prefetchedImagesForCells[indexPath.row]{
                cell.imageView.image = prefetchedImage
                prefetched = true
                prefetchedImagesForCells[indexPath.row] = nil
            }
            cell.configureCell(for: recipes[indexPath.row],prefetched: prefetched)
        }
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.foodTypeScrollView.isHidden = (self.navigationController?.navigationBar.isHidden)! ||  self.navigationItem.titleView != self.searchBar
        
        self.lastOffset = scrollView.contentOffset.y
        let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height
        let deltaOffset = maximumOffset - self.lastOffset
        
        if deltaOffset <= 0, recipes.count > 0 {
            if !loadingMore, !noMoreResults{
                search(offset: recipes.count, more: true)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView{
        
        let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "statusFooter", for: indexPath)
        if let footerView = footerView as? LoadingFooterCollectionReusableView{
            footerView.configurate(loading: !noMoreResults)
        }
        
        if recipes.count == 0{
            footerView.isHidden = true
        }
        return footerView
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width
        let height = 0.8 * width
        return CGSize(width: width, height: height)
    }
    
    func updateCollectionView(old: [Recipe]){
        collectionView.performBatchUpdates({
            for index in old.count ... (self.recipes.count - 1){
                self.collectionView.insertItems(at: [IndexPath(row: index, section: 0)])
            }
        })
    }
}

//MARK: -search bar
extension ExploreViewController: UISearchBarDelegate{
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.navigationItem.titleView = nil
        self.navigationItem.rightBarButtonItem = searchButton
        foodTypeScrollView.isHidden = true
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if !collectionView.visibleCells.isEmpty{
            collectionView.scrollToItem(at: IndexPath(row:0, section: 0), at: .top, animated: true)
        }
        searchBar.resignFirstResponder()
        currentQuery = searchBar.text ?? ""
        search()
    }
}

//MARK: -ExploreModelDelegate
extension ExploreViewController: ExploreModelDelegate{
    func modelDidLoadNewData() {
        recipes = model.recipes
        loadingMore = false
        noMoreResults = false
    }
    
    func modelCantLoadMore(){
        loadingMore = false
        noMoreResults = true
        if let footer = self.collectionView.supplementaryView(forElementKind: "UICollectionElementKindSectionFooter",
                                                              at: IndexPath(row: 0, section: 0)) as? LoadingFooterCollectionReusableView{
            footer.configurate(loading: !noMoreResults)
        }
        recipes = model.recipes
    }
    
    func modelHasNoConnection(){
        if loadingMore{
            modelCantLoadMore()
        }else{
            loadingMore = false
            noMoreResults = true
            recipes.removeAll()
        }
    }
}

//MARK: -prepareForSegue
extension ExploreViewController{
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowDetails"{
            if let cell = sender as? ExploreRecipeCell,
                let row = collectionView?.indexPath(for: cell)?.row{
                let vc = segue.destination as! DetailsViewController
                vc.image = cell.imageView.image
                vc.recipe = recipes[row]
            }
        }
    }
}

//MARK: -prefetching images
extension ExploreViewController: UICollectionViewDataSourcePrefetching{
    @available(iOS 10.0, *)
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for index in indexPaths{
            Alamofire.request(recipes[index.row].imageURL, method: HTTPMethod.get).response(completionHandler: {response in if let data = response.data{
                    self.prefetchedImagesForCells[index.row] = UIImage(data: data, scale: 1)
                }
            })
        }
    }
}


//MARK: -empty data set
extension ExploreViewController: DZNEmptyDataSetSource, DZNEmptyDataSetDelegate{
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let attributes = [NSForegroundColorAttributeName: self.view.tintColor as Any]
        return NSAttributedString(string: "Nothing to Show", attributes: attributes)
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let attributes = [NSForegroundColorAttributeName: self.view.tintColor as Any]
        return NSAttributedString(string: "Try to look for something else or check your internet connection", attributes: attributes)
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        return UIImage(named: "food")
    }
    
    func emptyDataSetWillDisappear(_ scrollView: UIScrollView!) {
        if let footer = self.collectionView.supplementaryView(forElementKind: "UICollectionElementKindSectionFooter",
                                                              at: IndexPath(row: 0, section: 0)) as? LoadingFooterCollectionReusableView{
            footer.isHidden = false
        }
    }
}




