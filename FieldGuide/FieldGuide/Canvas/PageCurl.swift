import PencilKit
import SwiftUI
import UIKit

/// Turns pages with UIKit's own page curl (`UIPageViewController` in `.pageCurl` style): the sheet
/// bends round as it lifts, follows the finger, and shows a faint mirror of the sketch on its back.
///
/// It lies over the live canvas, see-through and untouchable except for a strip along each outer
/// edge. When a turn starts, the sheet on top is filled with a snapshot of the page, so the
/// `PKCanvasView` underneath never moves; the page change is applied once the sheet has landed.
struct PageCurlOverlay: UIViewControllerRepresentable {
    let model: AppModel
    let pageSize: CGSize
    let edgeWidth: CGFloat
    let isEnabled: Bool
    let appearance: UIUserInterfaceStyle
    /// Called just before a curl changes the page, so the change needs no extra animation.
    let onTurn: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> CurlContainerController {
        let container = CurlContainerController(coordinator: context.coordinator)
        context.coordinator.container = container
        return container
    }

    func updateUIViewController(_ container: CurlContainerController, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.pageSize = pageSize
        coordinator.appearance = appearance
        coordinator.onTurn = onTurn
        container.touchView.edgeWidth = edgeWidth
        container.touchView.isEnabled = isEnabled && !model.canvas.isReadOnly
        container.touchView.canGoBack = model.previousPage != nil
        container.touchView.canGoForward = model.nextPage != nil
        if isEnabled {
            model.pageTurnHandler = { [weak coordinator] (offset: Int) -> Bool in
                coordinator?.turn(by: offset) ?? false
            }
        } else {
            model.pageTurnHandler = nil
        }
    }

    static func dismantleUIViewController(_ container: CurlContainerController, coordinator: Coordinator) {
        coordinator.model?.pageTurnHandler = nil
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
        weak var container: CurlContainerController?
        var model: AppModel?
        var pageSize: CGSize = .zero
        var appearance: UIUserInterfaceStyle = .light
        var onTurn: () -> Void = {}

        /// The see-through sheet that sits on top between turns.
        let idle = PageSheetController(page: nil)
        private var isTurning = false {
            didSet { container?.touchView.isTurning = isTurning }
        }

        // MARK: Turning

        /// Turns to the neighbouring page with the full curl (edge taps, header arrows).
        func turn(by offset: Int) -> Bool {
            guard !isTurning, let model, let pages = container?.pages, !model.canvas.isDrawing,
                  let target = offset > 0 ? model.nextPage : model.previousPage else { return false }
            prepareTopSheet()
            isTurning = true
            let sheet = PageSheetController(page: target)
            sheet.image = snapshot(of: target)
            pages.setViewControllers([sheet], direction: offset > 0 ? .forward : .reverse, animated: true) { [weak self, sheet] finished in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if finished, let page = sheet.page { self.land(on: page, direction: offset) }
                    self.reset()
                }
            }
            return true
        }

        /// Fills the top sheet with the page as it is right now, so it can curl away.
        private func prepareTopSheet() {
            guard let model, let current = model.currentPage else { return }
            idle.image = image(drawing: model.canvas.drawing, paper: current.paperStyle)
        }

        private func land(on page: Page, direction: Int) {
            onTurn()
            model?.open(page, direction: direction)
        }

        /// Back to the see-through sheet over the live canvas.
        private func reset() {
            idle.image = nil
            container?.pages.setViewControllers([idle], direction: .forward, animated: false)
            isTurning = false
        }

        private func snapshot(of page: Page) -> UIImage {
            image(drawing: CanvasStore.decode(page.drawingData), paper: page.paperStyle)
        }

        private func image(drawing: PKDrawing, paper: PaperStyle) -> UIImage {
            PageRenderer.sketchImage(drawing: drawing, paperStyle: paper, width: max(pageSize.width, 1), appearance: appearance)
        }

        // MARK: Data source

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            neighbour(of: viewController, offset: -1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            neighbour(of: viewController, offset: 1)
        }

        /// Only the sheet over the live canvas has neighbours; a sheet mid-turn never chains on.
        private func neighbour(of viewController: UIViewController, offset: Int) -> UIViewController? {
            guard viewController === idle, let model, !model.canvas.isDrawing,
                  let target = offset > 0 ? model.nextPage : model.previousPage else { return nil }
            prepareTopSheet()
            let sheet = PageSheetController(page: target)
            sheet.image = snapshot(of: target)
            return sheet
        }

        // MARK: Delegate

        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            isTurning = true
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let sheet = pageViewController.viewControllers?.first as? PageSheetController, let page = sheet.page,
               let model {
                land(on: page, direction: page.id == model.nextPage?.id ? 1 : -1)
            }
            reset()
        }

        // MARK: Gestures

        /// UIKit's own pan and tap only start on a page edge, and never while ink is going down.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = container?.touchView, !isTurning, model?.canvas.isDrawing == false else { return false }
            return view.isOnEdge(gestureRecognizer.location(in: view))
        }

        /// A drag that ends without starting a turn leaves the top sheet see-through again.
        @objc func edgeGestureChanged(_ recognizer: UIGestureRecognizer) {
            guard [.ended, .cancelled, .failed].contains(recognizer.state), !isTurning else { return }
            idle.image = nil
        }
    }
}

/// Hosts the page view controller. Its view lets every touch through to the canvas underneath
/// except on the outer edges, or while a page is turning.
final class CurlContainerController: UIViewController {
    let pages = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal,
                                     options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue])
    let touchView = EdgeTouchView()
    private unowned let coordinator: PageCurlOverlay.Coordinator

    init(coordinator: PageCurlOverlay.Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() { view = touchView }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        pages.isDoubleSided = false
        pages.dataSource = coordinator
        pages.delegate = coordinator
        pages.view.backgroundColor = .clear
        addChild(pages)
        pages.view.frame = view.bounds
        pages.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pages.view)
        pages.didMove(toParent: self)
        pages.setViewControllers([coordinator.idle], direction: .forward, animated: false)
        for recognizer in pages.gestureRecognizers {
            recognizer.delegate = coordinator
            recognizer.addTarget(coordinator, action: #selector(PageCurlOverlay.Coordinator.edgeGestureChanged(_:)))
        }
    }
}

/// Passes touches through except on a page edge that has a page to turn to, or mid-turn.
final class EdgeTouchView: UIView {
    var edgeWidth: CGFloat = 30
    var isEnabled = true
    var isTurning = false
    var canGoBack = false
    var canGoForward = false

    func isOnEdge(_ point: CGPoint) -> Bool {
        guard isEnabled, bounds.contains(point) else { return false }
        return (canGoForward && point.x >= bounds.maxX - edgeWidth) || (canGoBack && point.x <= bounds.minX + edgeWidth)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isTurning || isOnEdge(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// One sheet of paper: a snapshot of a page, or nothing (see-through) between turns.
final class PageSheetController: UIViewController {
    let page: Page?
    private let imageView = UIImageView()

    var image: UIImage? {
        didSet {
            imageView.image = image
            view.backgroundColor = image == nil ? .clear : UIColor(Theme.paper)
        }
    }

    init(page: Page?) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = image == nil ? .clear : UIColor(Theme.paper)
        imageView.contentMode = .scaleToFill
        imageView.frame = view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.image = image
        view.addSubview(imageView)
    }
}
